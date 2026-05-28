const elements = {
    form: document.getElementById('submit-form'),
    question: document.getElementById('question'),
    categorySelect: document.getElementById('category-select'),
    newCategory: document.getElementById('new-category'),
    optionInputs: Array.from(document.querySelectorAll('.option-input')),
    answerInputs: Array.from(document.querySelectorAll('input[name="answer"]')),
    message: document.getElementById('form-message')
};

async function getJson(url, options) {
    const response = await fetch(url, options);
    const data = await response.json();

    if (!response.ok) {
        throw new Error(data.message || `Request failed: ${response.status}`);
    }

    return data;
}

function setMessage(message, type = '') {
    elements.message.textContent = message;
    elements.message.dataset.type = type;
}

function getSelectedAnswerIndex() {
    return elements.answerInputs.findIndex((input) => input.checked);
}

function buildPayload() {
    const options = elements.optionInputs.map((input) => input.value.trim());
    const answerIndex = getSelectedAnswerIndex();

    return {
        question: elements.question.value.trim(),
        category: elements.categorySelect.value,
        newCategory: elements.newCategory.value.trim(),
        options,
        answer: answerIndex >= 0 ? options[answerIndex] : ''
    };
}

function validatePayload(payload) {
    const categoryCount = [payload.category, payload.newCategory].filter(Boolean).length;

    if (!payload.question) {
        return 'Question is required.';
    }

    if (categoryCount !== 1) {
        return 'Choose a category or add one new category.';
    }

    if (payload.options.some((option) => !option)) {
        return 'All four options are required.';
    }

    if (new Set(payload.options.map((option) => option.toLowerCase())).size !== 4) {
        return 'Options must be unique.';
    }

    if (!payload.answer) {
        return 'Choose one correct answer.';
    }

    return '';
}

async function loadCategories() {
    try {
        const data = await getJson('/categories');
        const categories = data.categories || [];

        categories.forEach((category) => {
            const option = document.createElement('option');

            option.value = category;
            option.textContent = category;
            elements.categorySelect.appendChild(option);
        });
    } catch (error) {
        console.error(error);
        setMessage('Categories could not be loaded.', 'error');
    }
}

async function submitQuestion(event) {
    event.preventDefault();

    const payload = buildPayload();
    const validationError = validatePayload(payload);

    if (validationError) {
        setMessage(validationError, 'error');
        return;
    }

    setMessage('Submitting question...');

    try {
        const data = await getJson('/submit', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(payload)
        });

        setMessage(data.message, 'success');

        if (payload.newCategory) {
            const option = document.createElement('option');

            option.value = payload.newCategory;
            option.textContent = payload.newCategory;
            elements.categorySelect.appendChild(option);
            elements.categorySelect.value = payload.newCategory;
            elements.newCategory.value = '';
        }
    } catch (error) {
        console.error(error);
        setMessage(error.message, 'error');
    }
}

function clearForm() {
    setMessage('');
    elements.categorySelect.value = '';
    elements.newCategory.value = '';
}

elements.form.addEventListener('submit', submitQuestion);
elements.form.addEventListener('reset', () => {
    window.setTimeout(clearForm, 0);
});

loadCategories();
