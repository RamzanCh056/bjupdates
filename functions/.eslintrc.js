module.exports = {
  env: {
    es6: true,
    node: true,
  },
  parserOptions: {
    ecmaVersion: 2018,
    sourceType: "module",
  },
  extends: [
    "eslint:recommended",
  ],
  rules: {
    "quotes": ["error", "double"],
    "indent": ["error", 2],
    "max-len": ["error", { "code": 200 }],
    "comma-dangle": ["error", "always-multiline"],
    "arrow-parens": ["error", "as-needed"],
    "no-console": "off", // Add this to allow console.log
  },
};