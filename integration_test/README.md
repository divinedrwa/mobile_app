# Flutter integration tests (C3)

Device-level payment E2E (Razorpay/PhonePe SDK + local API) runs on a physical emulator:

```bash
cd divine_app
flutter test integration_test/ -d <device_id>
```

CI runs VM-safe orchestrator contracts in `test/integration/payment_journey_orchestrator_test.dart`.

Add full widget/device journeys here when emulator is available in CI.
