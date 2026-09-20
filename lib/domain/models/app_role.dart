/// Passenger vs driver (rider) role in the single Ridons app.
enum AppRole {
  passenger,
  driver;

  bool get isPassenger => this == AppRole.passenger;
  bool get isDriver => this == AppRole.driver;
}
