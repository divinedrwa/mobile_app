/// Global hook for guard push / resume refresh (registered from [DivineApp]).
void Function()? onGuardDataRefreshRequested;

void requestGuardDataRefresh() {
  onGuardDataRefreshRequested?.call();
}
