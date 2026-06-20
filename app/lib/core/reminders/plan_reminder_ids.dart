/// 将 [taskId] 映射为稳定的本地通知 ID（1 … 2147483646）。
int notificationIdForTask(String taskId) {
  return taskId.hashCode.abs().remainder(2147483646) + 1;
}
