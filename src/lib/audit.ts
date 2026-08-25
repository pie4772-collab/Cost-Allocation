import prisma from "./db";
import type { Prisma } from "@prisma/client";

export interface AuditParams {
  userId?: string | null;
  action: string;
  entityType: string;
  entityId: string;
  beforeData?: unknown;
  afterData?: unknown;
  reason?: string;
  ipAddress?: string;
}

export async function createAuditLog(
  params: AuditParams,
  tx?: Prisma.TransactionClient
) {
  const client = tx ?? prisma;
  return client.auditLog.create({
    data: {
      userId: params.userId,
      action: params.action,
      entityType: params.entityType,
      entityId: params.entityId,
      beforeData: params.beforeData as Prisma.InputJsonValue,
      afterData: params.afterData as Prisma.InputJsonValue,
      reason: params.reason,
      ipAddress: params.ipAddress,
    },
  });
}

export async function getAuditLogs(filters?: {
  entityType?: string;
  entityId?: string;
  userId?: string;
  limit?: number;
  offset?: number;
}) {
  const where: Prisma.AuditLogWhereInput = {};
  if (filters?.entityType) where.entityType = filters.entityType;
  if (filters?.entityId) where.entityId = filters.entityId;
  if (filters?.userId) where.userId = filters.userId;

  const [logs, total] = await Promise.all([
    prisma.auditLog.findMany({
      where,
      include: { user: { select: { id: true, name: true, email: true } } },
      orderBy: { createdAt: "desc" },
      take: filters?.limit ?? 50,
      skip: filters?.offset ?? 0,
    }),
    prisma.auditLog.count({ where }),
  ]);

  return { logs, total };
}
