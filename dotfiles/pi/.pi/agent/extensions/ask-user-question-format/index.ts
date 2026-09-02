import type { ExtensionAPI } from '@earendil-works/pi-coding-agent';

const ASK_USER_QUESTION_TOOL_NAME = 'ask_user_question';
const ENVELOPE_PREFIX = 'User has answered your questions:';
const ENVELOPE_SUFFIX = "You can now continue with the user's answers in mind.";
const NO_INPUT_PLACEHOLDER = '(no input)';

interface QuestionAnswer {
  questionIndex: number;
  question: string;
  kind: 'option' | 'custom' | 'multi';
  answer: string | null;
  selected?: string[];
  notes?: string;
  preview?: string;
}

interface QuestionnaireResult {
  answers: QuestionAnswer[];
  cancelled: boolean;
  globalNote?: string;
}

function isQuestionAnswer(value: unknown): value is QuestionAnswer {
  if (!value || typeof value !== 'object') return false;

  const answer = value as Partial<QuestionAnswer>;
  if (
    typeof answer.questionIndex !== 'number' ||
    typeof answer.question !== 'string' ||
    !['option', 'custom', 'multi'].includes(answer.kind ?? '')
  ) {
    return false;
  }

  if (
    (answer.notes !== undefined && typeof answer.notes !== 'string') ||
    (answer.preview !== undefined && typeof answer.preview !== 'string')
  ) {
    return false;
  }

  if (answer.kind === 'multi') {
    return Array.isArray(answer.selected) && answer.selected.every((selected) => typeof selected === 'string');
  }

  return answer.answer === null || typeof answer.answer === 'string';
}

function isQuestionnaireResult(value: unknown): value is QuestionnaireResult {
  if (!value || typeof value !== 'object') return false;

  const result = value as Partial<QuestionnaireResult>;
  return (
    typeof result.cancelled === 'boolean' &&
    Array.isArray(result.answers) &&
    result.answers.every(isQuestionAnswer) &&
    (result.globalNote === undefined || typeof result.globalNote === 'string')
  );
}

function formatAnswer(answer: QuestionAnswer): string {
  if (answer.kind === 'multi') {
    return answer.selected && answer.selected.length > 0 ? answer.selected.join(', ') : NO_INPUT_PLACEHOLDER;
  }
  if (answer.kind === 'custom') {
    return answer.answer && answer.answer.length > 0 ? answer.answer : NO_INPUT_PLACEHOLDER;
  }
  return answer.answer ?? NO_INPUT_PLACEHOLDER;
}

function orderedAnswers(details: QuestionnaireResult): QuestionAnswer[] {
  return [...details.answers].sort((left, right) => left.questionIndex - right.questionIndex);
}

/** Reproduce the package's envelope so only untouched results are eligible for rewriting. */
export function formatOriginalQuestionnaireResult(details: unknown): string | undefined {
  if (!isQuestionnaireResult(details) || details.cancelled) return undefined;

  const segments = orderedAnswers(details).map((answer) => {
    const parts = [`"${answer.question}"="${formatAnswer(answer)}"`];
    if (answer.preview && answer.preview.length > 0) parts.push(`selected preview: ${answer.preview}`);
    if (answer.notes && answer.notes.length > 0) parts.push(`user notes: ${answer.notes}`);
    return `${parts.join('. ')}.`;
  });

  if (details.globalNote && details.globalNote.length > 0) {
    segments.push(`global note: ${details.globalNote}.`);
  }

  return segments.length > 0 ? `${ENVELOPE_PREFIX} ${segments.join(' ')} ${ENVELOPE_SUFFIX}` : undefined;
}

/** Build concise model-facing text from the questionnaire's structured result. */
export function formatQuestionnaireResult(details: unknown): string | undefined {
  if (!isQuestionnaireResult(details) || details.cancelled) return undefined;

  const sections = orderedAnswers(details).map((answer) => {
    const lines = [`Question: ${answer.question}`, `User Answer: ${formatAnswer(answer)}`];
    if (answer.notes && answer.notes.length > 0) lines.push(`User Notes: ${answer.notes}`);
    return lines.join('\n');
  });

  if (details.globalNote && details.globalNote.length > 0) {
    sections.push(`Global Note: ${details.globalNote}`);
  }

  return sections.length > 0 ? sections.join('\n\n') : undefined;
}

export default function askUserQuestionFormat(pi: ExtensionAPI): void {
  pi.on('tool_result', (event) => {
    if (event.toolName !== ASK_USER_QUESTION_TOOL_NAME) return;

    const originalText = formatOriginalQuestionnaireResult(event.details);
    const compactText = formatQuestionnaireResult(event.details);
    const [content] = event.content;
    if (
      originalText === undefined ||
      compactText === undefined ||
      event.content.length !== 1 ||
      content?.type !== 'text' ||
      content.text !== originalText
    ) {
      return;
    }

    return { content: [{ type: 'text', text: compactText }] };
  });
}
