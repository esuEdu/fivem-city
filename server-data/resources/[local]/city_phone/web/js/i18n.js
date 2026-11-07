// The phone's own texts in each language (locales/<language>.json); the player picks one in Settings
const LANGUAGES = ['en', 'pt-br'];
const dictionaries = {};
let current = 'en';

export async function loadLanguages() {
    await Promise.all(
        LANGUAGES.map((language) =>
            fetch(`locales/${language}.json`)
                .then((response) => response.json())
                .then((data) => { dictionaries[language] = data; })
                .catch(() => { dictionaries[language] = {}; }),
        ),
    );
}

export function setLanguage(language) {
    current = dictionaries[language] ? language : 'en';
    document.documentElement.lang = current;
}

export function language() {
    return current;
}

// t('lock.hint'), t('time.days')[0]; falls back to English, then to the key
export function t(key) {
    const find = (dictionary) => key.split('.').reduce((node, part) => (node == null ? undefined : node[part]), dictionary);
    return find(dictionaries[current]) ?? find(dictionaries.en) ?? key;
}

// An app's label in the current language
export function label(app) {
    return (app.labels && app.labels[current]) || app.label;
}
