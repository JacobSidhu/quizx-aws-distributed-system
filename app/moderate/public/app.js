// Browser controller for the authenticated moderation workflow: polls for the
// next submission, keeps the reservation alive while it is being reviewed, and
// sends approve and reject decisions to the API.
const elements = {
  accessToken: document.querySelector("#access-token"),
  answerList: document.querySelector("#answer-list"),
  approve: document.querySelector("#approve"),
  authPanel: document.querySelector("#auth-panel"),
  category: document.querySelector("#category"),
  categoryOptions: document.querySelector("#category-options"),
  connectionDot: document.querySelector("#connection-dot"),
  connectionText: document.querySelector("#connection-text"),
  emptyEditor: document.querySelector("#empty-editor"),
  form: document.querySelector("#moderation-form"),
  loadNext: document.querySelector("#load-next"),
  notice: document.querySelector("#notice"),
  proposedAnswer: document.querySelector("#proposed-answer"),
  question: document.querySelector("#question"),
  queueHeading: document.querySelector("#queue-heading"),
  queueMessage: document.querySelector("#queue-message"),
  reject: document.querySelector("#reject"),
  rejectionReason: document.querySelector("#rejection-reason"),
  saveToken: document.querySelector("#save-token"),
  submissionId: document.querySelector("#submission-id"),
  submissionMeta: document.querySelector("#submission-meta"),
  submittedAt: document.querySelector("#submitted-at"),
  validate: document.querySelector("#validate"),
  validationBadge: document.querySelector("#validation-badge"),
  validationErrors: document.querySelector("#validation-errors"),
};

const state = {
  current: null,
  heartbeat: null,
  pollIntervalMs: 5000,
  pollTimer: null,
  // sessionStorage keeps the token for this tab only; it is cleared when the
  // tab closes.
  token: sessionStorage.getItem("quizxModeratorToken") || "",
  visibilityHeartbeatMs: 60000,
};

function authorizationHeaders() {
  return state.token ? { Authorization: `Bearer ${state.token}` } : {};
}

// Fetch wrapper that adds the bearer token and surfaces API validation
// details on the thrown error.
async function api(path, options = {}) {
  const response = await fetch(path, {
    ...options,
    headers: {
      ...authorizationHeaders(),
      ...(options.body ? { "Content-Type": "application/json" } : {}),
      ...options.headers,
    },
  });

  if (response.status === 204) {
    return null;
  }

  const body = await response.json().catch(() => ({}));

  if (!response.ok) {
    const error = new Error(
      body.message || `Request failed (${response.status}).`,
    );
    error.details = body.details;
    error.status = response.status;
    throw error;
  }

  return body;
}

function showNotice(message) {
  elements.notice.textContent = message;
  elements.notice.hidden = false;
  window.setTimeout(() => {
    elements.notice.hidden = true;
  }, 5000);
}

function setConnection(online, message) {
  elements.connectionDot.classList.toggle("online", online);
  elements.connectionText.textContent = message;
}

function setBusy(busy) {
  [
    elements.approve,
    elements.reject,
    elements.validate,
    elements.loadNext,
  ].forEach((button) => {
    button.disabled = busy;
  });
}

function editedQuestion() {
  const options = [...elements.answerList.querySelectorAll(".answer-text")].map(
    (input) => input.value.trim(),
  );
  const selected = elements.answerList.querySelector(
    'input[type="radio"]:checked',
  );

  return {
    question: elements.question.value.trim(),
    category: elements.category.value.trim(),
    options,
    answer: selected ? options[Number(selected.value)] : "",
  };
}

function renderErrors(errors = []) {
  elements.validationErrors.hidden = errors.length === 0;
  elements.validationErrors.innerHTML = "";

  if (errors.length > 0) {
    const list = document.createElement("ul");
    errors.forEach((message) => {
      const item = document.createElement("li");
      item.textContent = message;
      list.append(item);
    });
    elements.validationErrors.append(list);
  }

  elements.validationBadge.textContent =
    errors.length > 0 ? "Needs review" : "Valid";
  elements.validationBadge.classList.toggle("valid", errors.length === 0);
}

function clearReview() {
  state.current = null;
  window.clearInterval(state.heartbeat);
  elements.form.hidden = true;
  elements.emptyEditor.hidden = false;
  elements.submissionMeta.hidden = true;
  elements.queueHeading.textContent = "Waiting for a submission";
  elements.queueMessage.textContent =
    "The service will keep checking for new questions.";
}

function schedulePoll() {
  window.clearTimeout(state.pollTimer);
  state.pollTimer = window.setTimeout(loadNext, state.pollIntervalMs);
}

function renderReview(review) {
  state.current = review;
  elements.form.hidden = false;
  elements.emptyEditor.hidden = true;
  elements.submissionMeta.hidden = false;
  elements.queueHeading.textContent = "Question reserved";
  elements.queueMessage.textContent = "Review before the reservation expires.";
  elements.submissionId.textContent = review.id;
  elements.submittedAt.textContent = review.submittedAt
    ? new Date(review.submittedAt).toLocaleString()
    : "Unknown";
  elements.proposedAnswer.textContent =
    review.proposedCorrectAnswer || "Not supplied";
  elements.question.value = review.question.question;
  elements.category.value = review.question.category;
  elements.rejectionReason.value = "";
  elements.answerList.innerHTML = "";

  function appendAnswer(option, index) {
    const row = document.createElement("div");
    row.className = "option-row";
    const input = document.createElement("input");
    input.className = "option-input answer-text";
    input.value = option;
    input.required = true;
    input.maxLength = 500;
    input.setAttribute("aria-label", `Answer option ${index + 1}`);
    const switchLabel = document.createElement("label");
    switchLabel.className = "answer-switch";
    const radio = document.createElement("input");
    radio.type = "radio";
    radio.name = "correct-answer";
    radio.value = `${index}`;
    radio.required = index === 0;
    radio.checked = option === review.question.answer;
    radio.setAttribute("aria-label", `Mark answer ${index + 1} as correct`);
    const track = document.createElement("span");
    track.className = "switch-track";
    const handle = document.createElement("span");
    handle.className = "switch-handle";
    const hiddenLabel = document.createElement("span");
    hiddenLabel.className = "sr-only";
    hiddenLabel.textContent = `Mark option ${index + 1} as correct`;
    track.append(handle);
    switchLabel.append(radio, track, hiddenLabel);
    row.append(input, switchLabel);
    elements.answerList.append(row);
  }

  review.question.options.forEach(appendAnswer);

  while (elements.answerList.children.length < 4) {
    const index = elements.answerList.children.length;
    appendAnswer("", index);
  }

  renderErrors(review.validationErrors);
  window.clearInterval(state.heartbeat);
  state.heartbeat = window.setInterval(
    extendVisibility,
    state.visibilityHeartbeatMs,
  );
}

async function loadCategories() {
  try {
    const result = await api("/moderate/categories");
    elements.categoryOptions.innerHTML = "";
    result.categories.forEach((category) => {
      const option = document.createElement("option");
      option.value = category;
      elements.categoryOptions.append(option);
    });
  } catch (error) {
    showNotice(error.message);
  }
}

async function loadNext() {
  if (state.current) {
    return;
  }

  setBusy(true);

  try {
    const review = await api("/moderate/next");
    setConnection(true, "Queue connected");

    if (review) {
      renderReview(review);
    } else {
      clearReview();
      schedulePoll();
    }
  } catch (error) {
    setConnection(
      false,
      error.status === 401 ? "Authentication required" : "Queue unavailable",
    );
    showNotice(error.message);
    schedulePoll();
  } finally {
    setBusy(false);
  }
}

async function validateEdits() {
  if (!state.current) return;
  setBusy(true);

  try {
    const result = await api(
      `/moderate/${encodeURIComponent(state.current.id)}`,
      {
        method: "PUT",
        body: JSON.stringify({
          reviewToken: state.current.reviewToken,
          question: editedQuestion(),
        }),
      },
    );
    renderErrors([]);
    showNotice("Edits are valid.");
    return result.question;
  } catch (error) {
    renderErrors(error.details || [error.message]);
    return null;
  } finally {
    setBusy(false);
  }
}

async function approve(event) {
  event.preventDefault();
  if (!state.current) return;
  setBusy(true);

  try {
    await api(`/moderate/${encodeURIComponent(state.current.id)}/approve`, {
      method: "POST",
      body: JSON.stringify({
        reviewToken: state.current.reviewToken,
        question: editedQuestion(),
      }),
    });
    showNotice("Question approved and sent downstream.");
    clearReview();
    await loadNext();
  } catch (error) {
    renderErrors(error.details || [error.message]);
  } finally {
    setBusy(false);
  }
}

async function reject() {
  if (!state.current || !window.confirm("Reject this submission?")) return;
  setBusy(true);

  try {
    await api(`/moderate/${encodeURIComponent(state.current.id)}/reject`, {
      method: "POST",
      body: JSON.stringify({
        reviewToken: state.current.reviewToken,
        reason: elements.rejectionReason.value,
      }),
    });
    showNotice("Question rejected. Nothing was sent downstream.");
    clearReview();
    await loadNext();
  } catch (error) {
    showNotice(error.message);
  } finally {
    setBusy(false);
  }
}

async function extendVisibility() {
  if (!state.current) return;

  try {
    const result = await api(
      `/moderate/${encodeURIComponent(state.current.id)}/visibility`,
      {
        method: "POST",
        body: JSON.stringify({ reviewToken: state.current.reviewToken }),
      },
    );
    state.current.reviewToken = result.reviewToken;
  } catch (error) {
    showNotice("The review reservation expired. Reloading the queue.");
    clearReview();
    schedulePoll();
  }
}

async function initialize() {
  try {
    const appConfig = await api("/moderate/config");
    state.pollIntervalMs = appConfig.pollIntervalMs;
    state.visibilityHeartbeatMs = appConfig.visibilityHeartbeatMs;
    elements.accessToken.value = state.token;
    await loadCategories();
    await loadNext();
  } catch (error) {
    setConnection(false, "Service unavailable");
    showNotice(error.message);
  }
}

elements.saveToken.addEventListener("click", async () => {
  state.token = elements.accessToken.value.trim();
  sessionStorage.setItem("quizxModeratorToken", state.token);
  clearReview();
  await loadCategories();
  await loadNext();
});
elements.loadNext.addEventListener("click", loadNext);
elements.validate.addEventListener("click", validateEdits);
elements.reject.addEventListener("click", reject);
elements.form.addEventListener("submit", approve);

initialize();
