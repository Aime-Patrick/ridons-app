enum RidonsAppRole {
  passenger,
  driver;

  bool get isPassenger => this == RidonsAppRole.passenger;
  bool get isDriver => this == RidonsAppRole.driver;
}
