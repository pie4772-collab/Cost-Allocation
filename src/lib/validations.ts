import { z } from "zod";

export const companySchema = z.object({
  code: z.string().min(1).max(20),
  nameKo: z.string().min(1),
  nameEn: z.string().optional(),
  companyType: z.enum(["DOMESTIC", "OVERSEAS"]),
  billingLanguage: z.enum(["KO", "EN"]).default("KO"),
  currency: z.enum(["KRW", "USD", "EUR", "JPY", "CNY"]).default("KRW"),
  contactEmail: z.string().email().optional().or(z.literal("")),
  contactPhone: z.string().optional(),
  sortOrder: z.number().int().default(0),
  address: z
    .object({
      line1: z.string().min(1),
      line2: z.string().optional(),
      city: z.string().optional(),
      state: z.string().optional(),
      postalCode: z.string().optional(),
      country: z.string().default("KR"),
    })
    .optional(),
});

export const companyUpdateSchema = companySchema
  .omit({ code: true })
  .partial()
  .extend({
    code: z.string().min(1).max(20).optional(),
    isActive: z.boolean().optional(),
    address: z
      .object({
        line1: z.string().min(1),
        line2: z.string().optional(),
        city: z.string().optional(),
        state: z.string().optional(),
        postalCode: z.string().optional(),
        country: z.string().default("KR"),
      })
      .optional(),
  });

export const costAccountSchema = z.object({
  code: z.string().min(1).optional(),
  nameKo: z.string().min(1),
  nameEn: z.string().optional(),
  description: z.string().optional(),
  sortOrder: z.number().int().default(0),
});

export const monthlyCostSchema = z.object({
  projectId: z.string(),
  costAccountId: z.string(),
  month: z.number().int().min(1).max(12),
  amount: z.number().int(),
});

export const allocationRateSchema = z.object({
  companyId: z.string(),
  rate: z.number().min(0).max(1),
});

export const rateVersionSchema = z.object({
  projectId: z.string(),
  rates: z.array(allocationRateSchema),
  notes: z.string().optional(),
});

export const allocationRunSchema = z.object({
  projectId: z.string(),
  rateVersionId: z.string(),
  runType: z.enum(["PREVIEW", "FINAL"]).default("PREVIEW"),
});

export const approvalActionSchema = z.object({
  requestId: z.string(),
  action: z.enum(["APPROVED", "REJECTED"]),
  comment: z.string().optional(),
});

export const periodSchema = z.object({
  year: z.number().int().min(2020).max(2100),
  half: z.number().int().min(1).max(2),
  label: z.string(),
  startDate: z.string().datetime(),
  endDate: z.string().datetime(),
});

export const projectSchema = z.object({
  periodId: z.string().optional(),
  name: z.string().min(1),
  notes: z.string().optional(),
});

const roleNameSchema = z.enum([
  "Admin",
  "CostManager",
  "AllocationManager",
  "Approver",
  "BillingManager",
  "Auditor",
  "Viewer",
]);

export const userCreateSchema = z.object({
  email: z.string().email(),
  name: z.string().trim().min(1),
  password: z.string().min(8, "비밀번호는 8자 이상이어야 합니다."),
  roles: z.array(roleNameSchema).min(1, "역할을 하나 이상 선택하세요."),
});

export const userUpdateSchema = z.object({
  name: z.string().trim().min(1).optional(),
  password: z
    .string()
    .min(8, "비밀번호는 8자 이상이어야 합니다.")
    .optional()
    .or(z.literal("")),
  roles: z.array(roleNameSchema).min(1).optional(),
  isActive: z.boolean().optional(),
});
