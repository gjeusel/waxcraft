import assert from 'node:assert/strict';
import test from 'node:test';
import type { ExtensionAPI } from '@earendil-works/pi-coding-agent';
import askUserQuestionFormat, { formatOriginalQuestionnaireResult, formatQuestionnaireResult } from './index.ts';

test('formats a single answer without envelope prose or preview duplication', () => {
  assert.equal(
    formatQuestionnaireResult({
      answers: [
        {
          questionIndex: 0,
          question: 'Which cache backend should we use?',
          kind: 'option',
          answer: 'Redis',
          preview: 'redis config omitted from the compact result',
        },
      ],
      cancelled: false,
    }),
    'Question: Which cache backend should we use?\nUser Answer: Redis',
  );
});

test('orders multiple answers and preserves multi-select, user notes, and the global note', () => {
  assert.equal(
    formatQuestionnaireResult({
      answers: [
        {
          questionIndex: 1,
          question: 'Which checks should run?',
          kind: 'multi',
          answer: null,
          selected: ['Unit tests', 'Integration tests'],
          notes: 'Skip browser tests for now.',
        },
        {
          questionIndex: 0,
          question: 'Which cache backend should we use?',
          kind: 'custom',
          answer: 'A local LRU cache',
        },
      ],
      cancelled: false,
      globalNote: 'Keep the implementation minimal.',
    }),
    [
      'Question: Which cache backend should we use?',
      'User Answer: A local LRU cache',
      '',
      'Question: Which checks should run?',
      'User Answer: Unit tests, Integration tests',
      'User Notes: Skip browser tests for now.',
      '',
      'Global Note: Keep the implementation minimal.',
    ].join('\n'),
  );
});

test('uses the package placeholder for an empty custom answer', () => {
  assert.equal(
    formatQuestionnaireResult({
      answers: [{ questionIndex: 0, question: 'Anything else?', kind: 'custom', answer: '' }],
      cancelled: false,
    }),
    'Question: Anything else?\nUser Answer: (no input)',
  );
});

test('leaves cancellations, empty submissions, and malformed details unchanged', () => {
  assert.equal(formatQuestionnaireResult({ answers: [], cancelled: true }), undefined);
  assert.equal(formatQuestionnaireResult({ answers: [], cancelled: false }), undefined);
  assert.equal(formatQuestionnaireResult({ answers: 'invalid', cancelled: false }), undefined);
});

test('reproduces the upstream envelope including previews and notes', () => {
  const details = {
    answers: [
      {
        questionIndex: 0,
        question: 'Proceed?',
        kind: 'option',
        answer: 'Yes',
        preview: 'proposed changes',
        notes: 'Keep it small',
      },
    ],
    cancelled: false,
    globalNote: 'No refactor',
  };

  assert.equal(
    formatOriginalQuestionnaireResult(details),
    'User has answered your questions: "Proceed?"="Yes". selected preview: proposed changes. user notes: Keep it small. global note: No refactor. You can now continue with the user\'s answers in mind.',
  );
});

test('rewrites only untouched successful ask_user_question results', () => {
  let toolResultHandler: ((event: any) => unknown) | undefined;
  const pi = {
    on(event: string, handler: (event: any) => unknown) {
      if (event === 'tool_result') toolResultHandler = handler;
    },
  } as unknown as ExtensionAPI;

  askUserQuestionFormat(pi);
  assert.ok(toolResultHandler);

  const details = {
    answers: [{ questionIndex: 0, question: 'Proceed?', kind: 'option', answer: 'Yes' }],
    cancelled: false,
  };
  const originalText = formatOriginalQuestionnaireResult(details);
  const originalContent = [{ type: 'text', text: originalText }];

  assert.equal(toolResultHandler({ toolName: 'read', details, content: originalContent }), undefined);
  assert.deepEqual(toolResultHandler({ toolName: 'ask_user_question', details, content: originalContent }), {
    content: [{ type: 'text', text: 'Question: Proceed?\nUser Answer: Yes' }],
  });
  assert.equal(
    toolResultHandler({
      toolName: 'ask_user_question',
      details: { answers: [], cancelled: true },
      content: [{ type: 'text', text: 'User declined to answer questions' }],
    }),
    undefined,
  );
});

test('does not overwrite a result changed by an earlier middleware', () => {
  let toolResultHandler: ((event: any) => unknown) | undefined;
  const pi = {
    on(event: string, handler: (event: any) => unknown) {
      if (event === 'tool_result') toolResultHandler = handler;
    },
  } as unknown as ExtensionAPI;

  askUserQuestionFormat(pi);
  assert.ok(toolResultHandler);

  const details = {
    answers: [{ questionIndex: 0, question: 'Token?', kind: 'custom', answer: 'secret value' }],
    cancelled: false,
  };
  const redactedContent = [
    {
      type: 'text',
      text: 'User has answered your questions: "Token?"="[REDACTED:generic-api-key]". You can now continue with the user\'s answers in mind.',
    },
  ];

  assert.equal(toolResultHandler({ toolName: 'ask_user_question', details, content: redactedContent }), undefined);
});
