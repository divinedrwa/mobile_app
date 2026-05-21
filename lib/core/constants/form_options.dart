/// Centralized form dropdown / chip options used across resident screens.
///
/// When the backend provides a configurable endpoint for any of these,
/// replace the constant here with a provider that fetches from the API.
/// Until then, keeping them in one file avoids scatter-editing 4+ screens
/// when a society wants to add "Swimming Pool Maintenance" as a complaint
/// category.
class FormOptions {
  FormOptions._();

  // ── Complaint categories ──────────────────────────────────────────
  static const complaintCategories = [
    'Plumbing',
    'Electrical',
    'Cleaning',
    'Security',
    'Parking',
    'Maintenance',
    'Noise',
    'Other',
  ];

  // ── Vehicle types ─────────────────────────────────────────────────
  // Display label → value sent to API.
  // Backend Prisma enum: TWO_WHEELER, FOUR_WHEELER, BICYCLE, OTHER.
  // We keep human-friendly labels and map to the API value when submitting.
  static const vehicleTypes = [
    'Car',
    'Bike',
    'Scooter',
    'Truck',
    'Other',
  ];

  // ── Daily help types ──────────────────────────────────────────────
  // Backend StaffType enum: MAID, COOK, DRIVER, GARDENER, OTHER.
  // "Nanny" exists in Prisma but not in the Zod validation layer.
  static const dailyHelpTypes = [
    'Maid',
    'Cook',
    'Driver',
    'Gardener',
    'Other',
  ];

  // ── Family member relationships ───────────────────────────────────
  static const familyRelationships = [
    'Spouse',
    'Son',
    'Daughter',
    'Father',
    'Mother',
    'Brother',
    'Sister',
    'Other',
  ];
}
