import { z } from "zod";

export const BudgetTierSchema = z.enum(["$", "$$", "$$$"]);
export const VibeSchema = z.enum(["cozy", "adventurous", "romantic", "low-key", "foodie", "outdoorsy"]);
export const DurationMinutesSchema = z.union([z.literal(90), z.literal(120), z.literal(180), z.literal(240)]);

export const GeneratePlanRequestSchema = z.object({
  locationLabel: z.string().trim().min(2).max(120),
  budgetTier: BudgetTierSchema,
  vibe: VibeSchema,
  noDrinking: z.boolean(),
  durationMinutes: DurationMinutesSchema,
  partnerLikes: z.string().trim().max(500).optional().default("")
});

export const PreviewStopSchema = z.object({
  order: z.union([z.literal(1), z.literal(2), z.literal(3)]),
  concept: z.string().trim().min(8).max(160),
  vibe: z.string().trim().min(4).max(80),
  reason: z.string().trim().min(12).max(220),
  personalizationSignal: z.string().trim().min(8).max(220)
});

const PreviewStopOneSchema = PreviewStopSchema.extend({ order: z.literal(1) });
const PreviewStopTwoSchema = PreviewStopSchema.extend({ order: z.literal(2) });
const PreviewStopThreeSchema = PreviewStopSchema.extend({ order: z.literal(3) });

export const LockedStopSchema = z.object({
  order: z.union([z.literal(1), z.literal(2), z.literal(3)]),
  venueName: z.string().trim().min(2).max(120),
  address: z.string().trim().min(2).max(180),
  appleMapsQuery: z.string().trim().min(2).max(220),
  durationMinutes: z.number().int().min(15).max(180),
  reason: z.string().trim().min(12).max(260),
  estimatedCost: z.string().trim().min(1).max(40)
});

const LockedStopOneSchema = LockedStopSchema.extend({ order: z.literal(1) });
const LockedStopTwoSchema = LockedStopSchema.extend({ order: z.literal(2) });
const LockedStopThreeSchema = LockedStopSchema.extend({ order: z.literal(3) });

export const DatePlanResponseSchema = z.object({
  id: z.string().trim().min(6).max(80),
  preview: z.object({
    title: z.string().trim().min(8).max(120),
    summaryBadges: z.array(z.string().trim().min(1).max(40)).min(2).max(6),
    stops: z.tuple([PreviewStopOneSchema, PreviewStopTwoSchema, PreviewStopThreeSchema])
  }),
  lockedPlan: z.object({
    totalEstimatedCost: z.string().trim().min(1).max(40),
    stops: z.tuple([LockedStopOneSchema, LockedStopTwoSchema, LockedStopThreeSchema])
  })
});

export type GeneratePlanRequest = z.infer<typeof GeneratePlanRequestSchema>;
export type DatePlanResponse = z.infer<typeof DatePlanResponseSchema>;
