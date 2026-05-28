const DEFAULT_CATEGORY = 'Science';

const elements = {
    categorySelect: document.getElementById('category-select'),
    selectedCategory: document.getElementById('selected-category'),
    questionCount: document.getElementById('question-count'),
    restartButton: document.getElementById('restart-button'),
    questions: document.getElementById('question-container')
};

let currentCategory = DEFAULT_CATEGORY;

async function getJson(url) {
    const response = await fetch(url);

    if (!response.ok) {
        throw new Error(`Request failed: ${response.status}`);
    }

    return response.json();
}

function getRequestedCount() {
    const count = Number.parseInt(elements.questionCount.value, 10);
    return Number.isFinite(count) && count > 0 ? count : 1;
}

function clearQuestions() {
    elements.questions.replaceChildren();
}

function showMessage(message) {
    const messageElement = document.createElement('p');

    messageElement.className = 'empty-state';
    messageElement.textContent = message;

    elements.questions.replaceChildren(messageElement);
}

function buildOptionButton(optionText) {
    const button = document.createElement('button');

    button.className = 'option-button';
    button.type = 'button';
    button.textContent = optionText;

    return button;
}

function buildQuestionCard(question, index) {
    const card = document.createElement('article');
    const title = document.createElement('h2');
    const optionList = document.createElement('div');

    card.className = 'question-block';
    title.className = 'question-title';
    optionList.className = 'options-list';

    title.textContent = `${index + 1}. ${question.question}`;

    question.options.forEach((option) => {
        optionList.appendChild(buildOptionButton(option));
    });

    card.append(title, optionList);

    return card;
}

function renderQuestions(questions) {
    clearQuestions();

    if (!questions.length) {
        showMessage('No questions found for this category.');
        return;
    }

    const fragment = document.createDocumentFragment();

    questions.forEach((question, index) => {
        fragment.appendChild(buildQuestionCard(question, index));
    });

    elements.questions.appendChild(fragment);
}

function syncSelectedCategory() {
    currentCategory = elements.categorySelect.value || currentCategory;
    elements.selectedCategory.textContent = currentCategory;
}

async function loadQuestions() {
    const count = getRequestedCount();

    elements.questionCount.value = count;
    syncSelectedCategory();
    showMessage('Loading questions...');

    try {
        const path = encodeURIComponent(currentCategory);
        const data = await getJson(`/questions/${path}?count=${count}`);

        renderQuestions(data.questions || []);
    } catch (error) {
        console.error(error);
        showMessage('Questions could not be loaded. Please try again.');
    }
}

async function loadCategories() {
    try {
        const data = await getJson('/categories');
        const categories = data.categories || [];

        if (!categories.length) {
            return;
        }

        elements.categorySelect.replaceChildren();

        categories.forEach((category) => {
            const option = document.createElement('option');

            option.value = category;
            option.textContent = category;
            elements.categorySelect.appendChild(option);
        });

        currentCategory = categories.includes(DEFAULT_CATEGORY) ? DEFAULT_CATEGORY : categories[0];
        elements.categorySelect.value = currentCategory;
        elements.selectedCategory.textContent = currentCategory;
    } catch (error) {
        console.error(error);
    }
}

// Only one answer can be selected per question.
elements.questions.addEventListener('click', (event) => {
    const selectedOption = event.target.closest('.option-button');

    if (!selectedOption) {
        return;
    }

    const optionList = selectedOption.closest('.options-list');
    const options = optionList.querySelectorAll('.option-button');

    options.forEach((option) => option.classList.remove('is-selected'));
    selectedOption.classList.add('is-selected');
});

// Category/count changes are applied when the user starts a new quiz.
elements.restartButton.addEventListener('click', loadQuestions);

loadCategories().then(loadQuestions);
