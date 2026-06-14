export type TaskSummary = { id: string; title: string; status: string };

export function tasksTextBudgetMax(): number {
  return Number(Deno.env.get("AI_RECOMMEND_TASKS_TEXT_MAX") ?? "32000");
}

/** Include full titles until adding the next task would exceed the text budget. */
export function selectTasksWithinBudget(
  tasks: TaskSummary[],
  textMax = tasksTextBudgetMax(),
): TaskSummary[] {
  let used = 0;
  const selected: TaskSummary[] = [];

  for (const task of tasks) {
    const title = String(task.title ?? "");
    const lineLen = title.length;
    if (selected.length > 0 && used + lineLen > textMax) {
      break;
    }
    selected.push({
      id: String(task.id),
      title,
      status: String(task.status ?? "inbox"),
    });
    used += lineLen;
  }

  return selected;
}
