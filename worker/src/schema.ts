import { z } from "zod";

export const VibeSchema = z.enum(["cozy", "adventurous", "romantic", "low-key", "foodie", "outdoorsy"]);
export const DurationMinutesSchema = z.union([z.literal(90), z.literal(120), z.literal(180), z.literal(240)]);

const CountryCurrencyMap: Record<string, string> = {
  AD: "EUR",
  AE: "AED",
  AT: "EUR",
  AU: "AUD",
  BE: "EUR",
  BR: "BRL",
  CA: "CAD",
  CH: "CHF",
  CN: "CNY",
  CY: "EUR",
  CZ: "CZK",
  DE: "EUR",
  DK: "DKK",
  EE: "EUR",
  ES: "EUR",
  FI: "EUR",
  FR: "EUR",
  GB: "GBP",
  GR: "EUR",
  HK: "HKD",
  HR: "EUR",
  HU: "HUF",
  IE: "EUR",
  IL: "ILS",
  IN: "INR",
  IT: "EUR",
  JP: "JPY",
  KR: "KRW",
  LT: "EUR",
  LU: "EUR",
  LV: "EUR",
  MC: "EUR",
  MT: "EUR",
  MX: "MXN",
  MY: "MYR",
  NL: "EUR",
  NO: "NOK",
  NZ: "NZD",
  PH: "PHP",
  PL: "PLN",
  PT: "EUR",
  SA: "SAR",
  SE: "SEK",
  SG: "SGD",
  SI: "EUR",
  SK: "EUR",
  TH: "THB",
  TR: "TRY",
  TW: "TWD",
  US: "USD",
  VN: "VND",
  ZA: "ZAR"
};

export function resolveCurrencyCode(countryCode: string): string | undefined {
  return CountryCurrencyMap[countryCode.trim().toUpperCase()];
}

const CountryCodeSchema = z.string()
  .trim()
  .length(2)
  .transform((value) => value.toUpperCase())
  .refine((value) => resolveCurrencyCode(value) !== undefined, "unsupported country code");

export const GeneratePlanRequestSchema = z.object({
  locationLabel: z.string().trim().min(2).max(120),
  budgetAmount: z.number().int().min(0).max(1_000_000),
  countryCode: CountryCodeSchema,
  vibe: VibeSchema,
  noDrinking: z.boolean(),
  durationMinutes: DurationMinutesSchema,
  partnerLikes: z.string().trim().max(500).optional().default(""),
  regenerationAttempt: z.number().int().min(0).max(20).optional().default(0),
  signedTransactionInfo: z.string().trim().min(20).max(10_000).optional()
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

const CostEstimateSchema = z.string()
  .trim()
  .min(1)
  .max(40)
  .refine((value) => value === "Free" || /\b[A-Z]{3}\b/.test(value), "cost estimate must be Free or include an ISO 4217 currency code");

export const LockedStopSchema = z.object({
  order: z.union([z.literal(1), z.literal(2), z.literal(3)]),
  venueName: z.string().trim().min(2).max(120),
  address: z.string().trim().min(2).max(180),
  appleMapsQuery: z.string().trim().min(2).max(220),
  durationMinutes: z.number().int().min(15).max(180),
  reason: z.string().trim().min(12).max(260),
  estimatedCost: CostEstimateSchema
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
    totalEstimatedCost: CostEstimateSchema,
    stops: z.tuple([LockedStopOneSchema, LockedStopTwoSchema, LockedStopThreeSchema])
  })
});

export const GeneratePlanPreviewResponseSchema = DatePlanResponseSchema
  .pick({ id: true, preview: true })
  .extend({
    planToken: z.string().trim().min(32).max(128)
  })
  .strict();

export const UnlockPlanRequestSchema = z.object({
  planToken: z.string().trim().min(32).max(128),
  signedTransactionInfo: z.string().trim().min(20).max(10_000)
}).strict();

export const UnlockPlanResponseSchema = DatePlanResponseSchema
  .pick({ id: true, lockedPlan: true })
  .strict();

export function validatePlanCostsForCurrency(plan: DatePlanResponse, currencyCode: string): void {
  const expectedCurrency = currencyCode.trim().toUpperCase();
  const stops = plan.lockedPlan.stops;
  const allStopsFree = stops.every((stop) => stop.estimatedCost === "Free");

  for (const stop of stops) {
    if (!isValidCostForCurrency(stop.estimatedCost, expectedCurrency)) {
      throw new Error("invalid_plan_currency");
    }
  }

  if (plan.lockedPlan.totalEstimatedCost === "Free") {
    if (!allStopsFree) {
      throw new Error("invalid_plan_currency");
    }
    return;
  }

  if (!isValidPaidCostForCurrency(plan.lockedPlan.totalEstimatedCost, expectedCurrency)) {
    throw new Error("invalid_plan_currency");
  }
}

function isValidCostForCurrency(value: string, currencyCode: string): boolean {
  return value === "Free" || isValidPaidCostForCurrency(value, currencyCode);
}

function isValidPaidCostForCurrency(value: string, currencyCode: string): boolean {
  return value.startsWith(`${currencyCode} `);
}

export type GeneratePlanRequest = z.infer<typeof GeneratePlanRequestSchema>;
export type DatePlanResponse = z.infer<typeof DatePlanResponseSchema>;
export type GeneratePlanPreviewResponse = z.infer<typeof GeneratePlanPreviewResponseSchema>;
export type UnlockPlanRequest = z.infer<typeof UnlockPlanRequestSchema>;
export type UnlockPlanResponse = z.infer<typeof UnlockPlanResponseSchema>;
