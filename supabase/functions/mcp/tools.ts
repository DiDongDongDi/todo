import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";

export const MCP_TOOLS = [
  {
    name: "list_tasks",
    description:
      "列出当前用户的任务，支持按状态过滤、按父任务过滤、分页。默认只返回未删除的任务。",
    inputSchema: {
      type: "object",
      properties: {
        status: {
          type: "string",
          enum: ["inbox", "someday", "archived", "trashed"],
          description: "按状态过滤",
        },
        parent_id: {
          type: "string",
          description: "传入时只返回该任务的子任务",
        },
        include_deleted: {
          type: "boolean",
          description: "是否包含已软删除的任务，默认 false",
        },
        limit: { type: "number", default: 50, maximum: 200 },
        offset: { type: "number", default: 0 },
      },
    },
  },
  {
    name: "get_task",
    description: "获取单个任务详情，含其子任务列表。",
    inputSchema: {
      type: "object",
      properties: {
        id: { type: "string", description: "任务 UUID" },
      },
      required: ["id"],
    },
  },
  {
    name: "create_task",
    description: "创建新任务。默认放入收集箱（inbox）。",
    inputSchema: {
      type: "object",
      properties: {
        title: { type: "string", description: "任务标题" },
        status: {
          type: "string",
          enum: ["inbox", "someday"],
          default: "inbox",
          description: "初始状态",
        },
        parent_id: { type: "string", description: "父任务 ID（创建子任务时传入）" },
        due_date: { type: "string", description: "截止日期 YYYY-MM-DD" },
        recurrence_type: {
          type: "string",
          enum: ["none", "daily", "monthly", "yearly"],
          default: "none",
          description: "重复类型",
        },
        is_starred: { type: "boolean", default: false, description: "是否加星" },
      },
      required: ["title"],
    },
  },
  {
    name: "update_task",
    description: "更新任务字段。只更新传入的字段，未传入的保持不变。",
    inputSchema: {
      type: "object",
      properties: {
        id: { type: "string", description: "任务 UUID" },
        title: { type: "string" },
        status: {
          type: "string",
          enum: ["inbox", "someday", "archived", "trashed"],
        },
        due_date: { type: "string", description: "YYYY-MM-DD，传 null 清除" },
        recurrence_type: {
          type: "string",
          enum: ["none", "daily", "monthly", "yearly"],
        },
        is_starred: { type: "boolean" },
        sort_order: { type: "number" },
      },
      required: ["id"],
    },
  },
  {
    name: "delete_task",
    description: "软删除任务（设置 deleted_at），不会真正删除数据。",
    inputSchema: {
      type: "object",
      properties: {
        id: { type: "string" },
      },
      required: ["id"],
    },
  },
  {
    name: "archive_task",
    description: "归档任务，状态变为 archived。",
    inputSchema: {
      type: "object",
      properties: {
        id: { type: "string" },
      },
      required: ["id"],
    },
  },
  {
    name: "trash_task",
    description: "将任务移入回收站，状态变为 trashed。",
    inputSchema: {
      type: "object",
      properties: {
        id: { type: "string" },
      },
      required: ["id"],
    },
  },
  {
    name: "restore_task",
    description: "将任务从回收站/归档/someday 恢复到收集箱（inbox）。",
    inputSchema: {
      type: "object",
      properties: {
        id: { type: "string" },
      },
      required: ["id"],
    },
  },
  {
    name: "someday_task",
    description: "将任务移到 Someday/Maybe 清单。",
    inputSchema: {
      type: "object",
      properties: {
        id: { type: "string" },
      },
      required: ["id"],
    },
  },
  {
    name: "create_subtask",
    description: "为指定任务创建子任务。",
    inputSchema: {
      type: "object",
      properties: {
        parent_id: { type: "string", description: "父任务 ID" },
        title: { type: "string" },
        due_date: { type: "string", description: "截止日期 YYYY-MM-DD" },
      },
      required: ["parent_id", "title"],
    },
  },
  {
    name: "list_playlists",
    description: "列出当前用户的所有任务清单。",
    inputSchema: { type: "object", properties: {} },
  },
  {
    name: "get_playlist",
    description: "获取清单详情及包含的任务。",
    inputSchema: {
      type: "object",
      properties: {
        id: { type: "string" },
      },
      required: ["id"],
    },
  },
  {
    name: "create_playlist",
    description: "创建新清单。",
    inputSchema: {
      type: "object",
      properties: {
        title: { type: "string" },
        task_ids: {
          type: "array",
          items: { type: "string" },
          description: "任务 UUID 列表",
        },
        source_query: { type: "string", description: "原始查询文本（可选）" },
      },
      required: ["title"],
    },
  },
  {
    name: "update_playlist",
    description: "更新清单标题或任务列表。",
    inputSchema: {
      type: "object",
      properties: {
        id: { type: "string" },
        title: { type: "string" },
        task_ids: { type: "array", items: { type: "string" } },
      },
      required: ["id"],
    },
  },
  {
    name: "delete_playlist",
    description: "删除清单（不影响清单内的任务）。",
    inputSchema: {
      type: "object",
      properties: {
        id: { type: "string" },
      },
      required: ["id"],
    },
  },
  {
    name: "list_templates",
    description: "列出当前用户的任务模板。",
    inputSchema: { type: "object", properties: {} },
  },
  {
    name: "create_task_from_template",
    description: "从模板创建任务（含子任务）。",
    inputSchema: {
      type: "object",
      properties: {
        template_id: { type: "string" },
      },
      required: ["template_id"],
    },
  },
];

function now(): string {
  return new Date().toISOString();
}

function validateUUID(id: unknown, name: string): string {
  const s = String(id ?? "").trim();
  if (
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s)
  ) {
    throw new Error(`${name} 必须是有效的 UUID`);
  }
  return s;
}

function validateStatus(
  status: unknown,
  allowed: string[],
): string {
  const s = String(status ?? "inbox");
  if (!allowed.includes(s)) {
    throw new Error(`status 必须是 ${allowed.join("/")} 之一`);
  }
  return s;
}

async function getOwnedTask(
  client: SupabaseClient,
  userId: string,
  id: string,
) {
  const { data, error } = await client
    .from("tasks")
    .select("id, user_id, status, deleted_at")
    .eq("id", id)
    .eq("user_id", userId)
    .maybeSingle();
  if (error) throw error;
  if (!data) throw new Error("任务不存在或不属于你");
  return data;
}

export async function handleTool(
  client: SupabaseClient,
  userId: string,
  name: string,
  args: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  switch (name) {
    // ---- 任务 CRUD ----
    case "list_tasks": {
      let query = client
        .from("tasks")
        .select("*")
        .eq("user_id", userId)
        .order("sort_order", { ascending: false });

      if (args.status) {
        query = query.eq("status", validateStatus(args.status, [
          "inbox",
          "someday",
          "archived",
          "trashed",
        ]));
      }
      if (args.parent_id) {
        query = query.eq("parent_id", validateUUID(args.parent_id, "parent_id"));
      }
      if (args.include_deleted !== true) {
        query = query.is("deleted_at", null);
      }

      const limit = Math.min(Math.max(Number(args.limit ?? 50), 1), 200);
      const offset = Math.max(Number(args.offset ?? 0), 0);
      query = query.range(offset, offset + limit - 1);

      const { data, error } = await query;
      if (error) throw error;
      return { tasks: data ?? [], count: data?.length ?? 0 };
    }

    case "get_task": {
      const id = validateUUID(args.id, "id");
      await getOwnedTask(client, userId, id);

      const { data, error } = await client
        .from("tasks")
        .select("*")
        .eq("id", id)
        .eq("user_id", userId)
        .single();
      if (error) throw error;

      const { data: subtasks } = await client
        .from("tasks")
        .select("*")
        .eq("parent_id", id)
        .eq("user_id", userId)
        .is("deleted_at", null)
        .order("sort_order", { ascending: false });

      return { ...data, subtasks: subtasks ?? [] };
    }

    case "create_task": {
      const title = String(args.title ?? "").trim();
      if (!title) throw new Error("title 不能为空");
      if (title.length > 500) throw new Error("title 过长（最多 500 字符）");

      const status = validateStatus(args.status, ["inbox", "someday"]);
      const recurrenceType = String(args.recurrence_type ?? "none");
      if (!["none", "daily", "monthly", "yearly"].includes(recurrenceType)) {
        throw new Error("recurrence_type 必须是 none/daily/monthly/yearly");
      }

      const dueDate = args.due_date != null && args.due_date !== ""
        ? String(args.due_date)
        : null;
      if (dueDate && !/^\d{4}-\d{2}-\d{2}$/.test(dueDate)) {
        throw new Error("due_date 格式必须是 YYYY-MM-DD");
      }

      const parentId = args.parent_id != null && args.parent_id !== ""
        ? validateUUID(args.parent_id, "parent_id")
        : null;
      if (parentId) {
        const parent = await getOwnedTask(client, userId, parentId);
        if (parent.deleted_at) throw new Error("父任务已删除");
        if (parent.status === "trashed") throw new Error("父任务在回收站中");
      }

      const payload: Record<string, unknown> = {
        user_id: userId,
        title,
        status,
        sort_order: Date.now(),
        sync_version: 1,
        created_at: now(),
        updated_at: now(),
        attachments: [],
        transcription_status: "none",
        recurrence_type: recurrenceType,
        is_daily: recurrenceType === "daily",
        check_in_target: 1,
        check_in_count: 0,
        is_starred: Boolean(args.is_starred),
      };
      if (dueDate) payload.due_date = dueDate;
      if (parentId) payload.parent_id = parentId;
      if (status === "someday") payload.someday_at = now();

      const { data, error } = await client
        .from("tasks")
        .insert(payload)
        .select()
        .single();
      if (error) {
        if (error.message.includes("task_limit_exceeded")) {
          throw new Error("任务数量已达上限（5000），请先清理");
        }
        throw error;
      }
      return data;
    }

    case "update_task": {
      const id = validateUUID(args.id, "id");
      await getOwnedTask(client, userId, id);

      const patch: Record<string, unknown> = {
        updated_at: now(),
      };

      if (args.title !== undefined) {
        const title = String(args.title).trim();
        if (!title) throw new Error("title 不能为空");
        if (title.length > 500) throw new Error("title 过长（最多 500 字符）");
        patch.title = title;
      }
      if (args.status !== undefined) {
        const status = validateStatus(args.status, [
          "inbox",
          "someday",
          "archived",
          "trashed",
        ]);
        patch.status = status;
        if (status === "archived") patch.archived_at = now();
        if (status === "trashed") patch.trashed_at = now();
        if (status === "someday") patch.someday_at = now();
      }
      if (args.due_date !== undefined) {
        if (args.due_date === null) {
          patch.due_date = null;
        } else {
          const dueDate = String(args.due_date);
          if (!/^\d{4}-\d{2}-\d{2}$/.test(dueDate)) {
            throw new Error("due_date 格式必须是 YYYY-MM-DD");
          }
          patch.due_date = dueDate;
        }
      }
      if (args.recurrence_type !== undefined) {
        const r = String(args.recurrence_type);
        if (!["none", "daily", "monthly", "yearly"].includes(r)) {
          throw new Error("recurrence_type 必须是 none/daily/monthly/yearly");
        }
        patch.recurrence_type = r;
        patch.is_daily = r === "daily";
      }
      if (args.is_starred !== undefined) patch.is_starred = Boolean(args.is_starred);
      if (args.sort_order !== undefined) patch.sort_order = Number(args.sort_order);

      const { data: current, error: fetchError } = await client
        .from("tasks")
        .select("sync_version")
        .eq("id", id)
        .single();
      if (fetchError) throw fetchError;
      patch.sync_version = (current?.sync_version ?? 0) + 1;

      const { data, error } = await client
        .from("tasks")
        .update(patch)
        .eq("id", id)
        .eq("user_id", userId)
        .select()
        .single();
      if (error) throw error;
      return data;
    }

    case "delete_task": {
      const id = validateUUID(args.id, "id");
      await getOwnedTask(client, userId, id);

      const { data, error } = await client
        .from("tasks")
        .update({
          deleted_at: now(),
          updated_at: now(),
          sync_version: (
            await client.from("tasks").select("sync_version").eq("id", id).single()
          ).data?.sync_version + 1 || 1,
        })
        .eq("id", id)
        .eq("user_id", userId)
        .select()
        .single();
      if (error) throw error;
      return { message: "任务已软删除", task: data };
    }

    // ---- 状态快捷操作 ----
    case "archive_task":
    case "trash_task":
    case "restore_task":
    case "someday_task": {
      const id = validateUUID(args.id, "id");
      await getOwnedTask(client, userId, id);

      const statusMap: Record<string, string> = {
        archive_task: "archived",
        trash_task: "trashed",
        restore_task: "inbox",
        someday_task: "someday",
      };
      const targetStatus = statusMap[name];

      const patch: Record<string, unknown> = {
        status: targetStatus,
        updated_at: now(),
      };
      if (targetStatus === "archived") patch.archived_at = now();
      if (targetStatus === "trashed") patch.trashed_at = now();
      if (targetStatus === "someday") patch.someday_at = now();

      const { data: current } = await client
        .from("tasks")
        .select("sync_version")
        .eq("id", id)
        .single();
      patch.sync_version = (current?.sync_version ?? 0) + 1;

      const { data, error } = await client
        .from("tasks")
        .update(patch)
        .eq("id", id)
        .eq("user_id", userId)
        .select()
        .single();
      if (error) throw error;
      return { message: `任务已切换到 ${targetStatus}`, task: data };
    }

    case "create_subtask": {
      const parentId = validateUUID(args.parent_id, "parent_id");
      const parent = await getOwnedTask(client, userId, parentId);
      if (parent.deleted_at) throw new Error("父任务已删除");
      if (parent.status === "trashed") throw new Error("父任务在回收站中");

      const title = String(args.title ?? "").trim();
      if (!title) throw new Error("title 不能为空");
      if (title.length > 500) throw new Error("title 过长（最多 500 字符）");

      const dueDate = args.due_date != null && args.due_date !== ""
        ? String(args.due_date)
        : null;
      if (dueDate && !/^\d{4}-\d{2}-\d{2}$/.test(dueDate)) {
        throw new Error("due_date 格式必须是 YYYY-MM-DD");
      }

      const payload: Record<string, unknown> = {
        user_id: userId,
        title,
        status: "inbox",
        parent_id: parentId,
        sort_order: Date.now(),
        sync_version: 1,
        created_at: now(),
        updated_at: now(),
        attachments: [],
        transcription_status: "none",
        recurrence_type: "none",
        is_daily: false,
        check_in_target: 1,
        check_in_count: 0,
        is_starred: false,
      };
      if (dueDate) payload.due_date = dueDate;

      const { data, error } = await client
        .from("tasks")
        .insert(payload)
        .select()
        .single();
      if (error) {
        if (error.message.includes("task_limit_exceeded")) {
          throw new Error("任务数量已达上限（5000），请先清理");
        }
        throw error;
      }
      return data;
    }

    // ---- 清单 ----
    case "list_playlists": {
      const { data, error } = await client
        .from("task_playlists")
        .select("*")
        .eq("user_id", userId)
        .order("updated_at", { ascending: false });
      if (error) throw error;
      return { playlists: data ?? [], count: data?.length ?? 0 };
    }

    case "get_playlist": {
      const id = validateUUID(args.id, "id");
      const { data, error } = await client
        .from("task_playlists")
        .select("*")
        .eq("id", id)
        .eq("user_id", userId)
        .maybeSingle();
      if (error) throw error;
      if (!data) throw new Error("清单不存在或不属于你");

      const taskIds = (data.task_ids as string[]) ?? [];
      if (taskIds.length === 0) return { ...data, tasks: [] };

      const { data: tasks } = await client
        .from("tasks")
        .select("*")
        .in("id", taskIds)
        .eq("user_id", userId)
        .is("deleted_at", null);
      return { ...data, tasks: tasks ?? [] };
    }

    case "create_playlist": {
      const title = String(args.title ?? "").trim();
      if (!title) throw new Error("title 不能为空");
      if (title.length > 200) throw new Error("title 过长（最多 200 字符）");

      const taskIds = Array.isArray(args.task_ids)
        ? args.task_ids.map((id) => validateUUID(id, "task_id"))
        : [];

      const payload: Record<string, unknown> = {
        user_id: userId,
        title,
        task_ids: taskIds,
        sync_version: 1,
        created_at: now(),
        updated_at: now(),
      };
      if (args.source_query != null) {
        payload.source_query = String(args.source_query).slice(0, 500);
      }

      const { data, error } = await client
        .from("task_playlists")
        .insert(payload)
        .select()
        .single();
      if (error) throw error;
      return data;
    }

    case "update_playlist": {
      const id = validateUUID(args.id, "id");

      const { data: existing, error: fetchError } = await client
        .from("task_playlists")
        .select("sync_version")
        .eq("id", id)
        .eq("user_id", userId)
        .maybeSingle();
      if (fetchError) throw fetchError;
      if (!existing) throw new Error("清单不存在或不属于你");

      const patch: Record<string, unknown> = {
        updated_at: now(),
        sync_version: (existing.sync_version ?? 0) + 1,
      };
      if (args.title !== undefined) {
        const title = String(args.title).trim();
        if (!title) throw new Error("title 不能为空");
        if (title.length > 200) throw new Error("title 过长（最多 200 字符）");
        patch.title = title;
      }
      if (args.task_ids !== undefined) {
        patch.task_ids = Array.isArray(args.task_ids)
          ? args.task_ids.map((tid) => validateUUID(tid, "task_id"))
          : [];
      }

      const { data, error } = await client
        .from("task_playlists")
        .update(patch)
        .eq("id", id)
        .eq("user_id", userId)
        .select()
        .single();
      if (error) throw error;
      return data;
    }

    case "delete_playlist": {
      const id = validateUUID(args.id, "id");

      const { error } = await client
        .from("task_playlists")
        .delete()
        .eq("id", id)
        .eq("user_id", userId);
      if (error) throw error;
      return { message: "清单已删除" };
    }

    // ---- 模板 ----
    case "list_templates": {
      const { data, error } = await client
        .from("task_templates")
        .select("*")
        .eq("user_id", userId)
        .is("deleted_at", null)
        .order("updated_at", { ascending: false });
      if (error) throw error;
      return { templates: data ?? [], count: data?.length ?? 0 };
    }

    case "create_task_from_template": {
      const templateId = validateUUID(args.template_id, "template_id");

      const { data: tpl, error: tplError } = await client
        .from("task_templates")
        .select("*")
        .eq("id", templateId)
        .eq("user_id", userId)
        .is("deleted_at", null)
        .maybeSingle();
      if (tplError) throw tplError;
      if (!tpl) throw new Error("模板不存在或不属于你");

      const recurrenceType = String(tpl.recurrence_type ?? "none");
      const parentPayload: Record<string, unknown> = {
        user_id: userId,
        title: tpl.title ?? "",
        status: "inbox",
        sort_order: Date.now(),
        sync_version: 1,
        created_at: now(),
        updated_at: now(),
        attachments: tpl.attachments ?? [],
        transcription_status: "none",
        recurrence_type: recurrenceType,
        is_daily: recurrenceType === "daily",
        check_in_target: tpl.check_in_target ?? 1,
        check_in_count: 0,
        is_starred: false,
      };
      if (tpl.due_date) parentPayload.due_date = tpl.due_date;

      const { data: parentTask, error: parentError } = await client
        .from("tasks")
        .insert(parentPayload)
        .select()
        .single();
      if (parentError) {
        if (parentError.message.includes("task_limit_exceeded")) {
          throw new Error("任务数量已达上限（5000），请先清理");
        }
        throw parentError;
      }

      const subtaskTitles = (tpl.subtask_titles as string[]) ?? [];
      const subtasks = [];
      for (const title of subtaskTitles) {
        if (!title || typeof title !== "string") continue;
        const subPayload = {
          user_id: userId,
          title: title.trim(),
          status: "inbox",
          parent_id: parentTask.id,
          sort_order: Date.now() + subtasks.length,
          sync_version: 1,
          created_at: now(),
          updated_at: now(),
          attachments: [],
          transcription_status: "none",
          recurrence_type: "none",
          is_daily: false,
          check_in_target: 1,
          check_in_count: 0,
          is_starred: false,
        };
        const { data: subTask, error: subError } = await client
          .from("tasks")
          .insert(subPayload)
          .select()
          .single();
        if (subError) {
          console.error("create subtask from template error:", subError);
          continue;
        }
        subtasks.push(subTask);
      }

      return {
        task: parentTask,
        subtasks,
        message: `已从模板创建任务（含 ${subtasks.length} 个子任务）`,
      };
    }

    default:
      throw new Error(`Unknown tool: ${name}`);
  }
}
