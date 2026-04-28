namespace VolunteerHub.Domain.Enums;

public enum UserRole
{
    Volunteer = 0,
    Admin = 1,
    SuperAdmin = 2
}

public enum ShiftStatus
{
    Pending = 0,
    Registered = 1,
    Approved = 2,
    Rejected = 3,
    Completed = 4,
    Cancelled = 5
}

public enum DonationStatus
{
    Pending = 0,
    Completed = 1,
    Failed = 2,
    Refunded = 3
}

public enum EventStatus
{
    Draft = 0,
    Published = 1,
    Cancelled = 2,
    Completed = 3
}

public enum NotificationType
{
    ShiftReminder = 0,
    ShiftApproved = 1,
    ShiftRejected = 2,
    ShiftRegistration = 3,
    NewEvent = 4,
    DonationReceived = 5,
    General = 6,
    EventRegistration = 7,
    EventRegistrationCancelled = 8,
    ShiftCheckIn = 9,
    ShiftCheckOut = 10
}
