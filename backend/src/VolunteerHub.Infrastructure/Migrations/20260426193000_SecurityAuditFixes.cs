using System;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using VolunteerHub.Infrastructure.Data;

#nullable disable

namespace VolunteerHub.Infrastructure.Migrations;

[DbContext(typeof(ApplicationDbContext))]
[Migration("20260426193000_SecurityAuditFixes")]
public partial class SecurityAuditFixes : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropForeignKey("FK_Donations_Campaigns_CampaignId", "Donations");
        migrationBuilder.DropForeignKey("FK_EventRegistrations_Events_EventId", "EventRegistrations");
        migrationBuilder.DropForeignKey("FK_EventRegistrations_Users_UserId", "EventRegistrations");
        migrationBuilder.DropForeignKey("FK_ShiftRegistrations_Shifts_ShiftId", "ShiftRegistrations");
        migrationBuilder.DropForeignKey("FK_ShiftRegistrations_Users_UserId", "ShiftRegistrations");
        migrationBuilder.DropForeignKey("FK_Shifts_Events_EventId", "Shifts");
        migrationBuilder.DropForeignKey("FK_VolunteerHistories_Users_UserId", "VolunteerHistories");

        migrationBuilder.AddColumn<DateTime>(
            name: "ApprovedAt",
            table: "ShiftRegistrations",
            type: "datetime2",
            nullable: true);

        migrationBuilder.AddColumn<int>(
            name: "ApprovedByUserId",
            table: "ShiftRegistrations",
            type: "int",
            nullable: true);

        migrationBuilder.AddColumn<DateTime>(
            name: "FinalApprovedAt",
            table: "ShiftRegistrations",
            type: "datetime2",
            nullable: true);

        migrationBuilder.AddColumn<int>(
            name: "FinalApprovedByUserId",
            table: "ShiftRegistrations",
            type: "int",
            nullable: true);

        migrationBuilder.AddColumn<DateTime>(
            name: "RejectedAt",
            table: "ShiftRegistrations",
            type: "datetime2",
            nullable: true);

        migrationBuilder.AddColumn<int>(
            name: "RejectedByUserId",
            table: "ShiftRegistrations",
            type: "int",
            nullable: true);

        migrationBuilder.AddForeignKey(
            name: "FK_Donations_Campaigns_CampaignId",
            table: "Donations",
            column: "CampaignId",
            principalTable: "Campaigns",
            principalColumn: "Id",
            onDelete: ReferentialAction.Restrict);

        migrationBuilder.AddForeignKey(
            name: "FK_EventRegistrations_Events_EventId",
            table: "EventRegistrations",
            column: "EventId",
            principalTable: "Events",
            principalColumn: "Id",
            onDelete: ReferentialAction.Restrict);

        migrationBuilder.AddForeignKey(
            name: "FK_EventRegistrations_Users_UserId",
            table: "EventRegistrations",
            column: "UserId",
            principalTable: "Users",
            principalColumn: "Id",
            onDelete: ReferentialAction.Restrict);

        migrationBuilder.AddForeignKey(
            name: "FK_ShiftRegistrations_Shifts_ShiftId",
            table: "ShiftRegistrations",
            column: "ShiftId",
            principalTable: "Shifts",
            principalColumn: "Id",
            onDelete: ReferentialAction.Restrict);

        migrationBuilder.AddForeignKey(
            name: "FK_ShiftRegistrations_Users_UserId",
            table: "ShiftRegistrations",
            column: "UserId",
            principalTable: "Users",
            principalColumn: "Id",
            onDelete: ReferentialAction.Restrict);

        migrationBuilder.AddForeignKey(
            name: "FK_Shifts_Events_EventId",
            table: "Shifts",
            column: "EventId",
            principalTable: "Events",
            principalColumn: "Id",
            onDelete: ReferentialAction.Restrict);

        migrationBuilder.AddForeignKey(
            name: "FK_VolunteerHistories_Users_UserId",
            table: "VolunteerHistories",
            column: "UserId",
            principalTable: "Users",
            principalColumn: "Id",
            onDelete: ReferentialAction.Restrict);
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropForeignKey("FK_Donations_Campaigns_CampaignId", "Donations");
        migrationBuilder.DropForeignKey("FK_EventRegistrations_Events_EventId", "EventRegistrations");
        migrationBuilder.DropForeignKey("FK_EventRegistrations_Users_UserId", "EventRegistrations");
        migrationBuilder.DropForeignKey("FK_ShiftRegistrations_Shifts_ShiftId", "ShiftRegistrations");
        migrationBuilder.DropForeignKey("FK_ShiftRegistrations_Users_UserId", "ShiftRegistrations");
        migrationBuilder.DropForeignKey("FK_Shifts_Events_EventId", "Shifts");
        migrationBuilder.DropForeignKey("FK_VolunteerHistories_Users_UserId", "VolunteerHistories");

        migrationBuilder.DropColumn("ApprovedAt", "ShiftRegistrations");
        migrationBuilder.DropColumn("ApprovedByUserId", "ShiftRegistrations");
        migrationBuilder.DropColumn("FinalApprovedAt", "ShiftRegistrations");
        migrationBuilder.DropColumn("FinalApprovedByUserId", "ShiftRegistrations");
        migrationBuilder.DropColumn("RejectedAt", "ShiftRegistrations");
        migrationBuilder.DropColumn("RejectedByUserId", "ShiftRegistrations");

        migrationBuilder.AddForeignKey(
            name: "FK_Donations_Campaigns_CampaignId",
            table: "Donations",
            column: "CampaignId",
            principalTable: "Campaigns",
            principalColumn: "Id",
            onDelete: ReferentialAction.Cascade);

        migrationBuilder.AddForeignKey(
            name: "FK_EventRegistrations_Events_EventId",
            table: "EventRegistrations",
            column: "EventId",
            principalTable: "Events",
            principalColumn: "Id",
            onDelete: ReferentialAction.Cascade);

        migrationBuilder.AddForeignKey(
            name: "FK_EventRegistrations_Users_UserId",
            table: "EventRegistrations",
            column: "UserId",
            principalTable: "Users",
            principalColumn: "Id",
            onDelete: ReferentialAction.Cascade);

        migrationBuilder.AddForeignKey(
            name: "FK_ShiftRegistrations_Shifts_ShiftId",
            table: "ShiftRegistrations",
            column: "ShiftId",
            principalTable: "Shifts",
            principalColumn: "Id",
            onDelete: ReferentialAction.Cascade);

        migrationBuilder.AddForeignKey(
            name: "FK_ShiftRegistrations_Users_UserId",
            table: "ShiftRegistrations",
            column: "UserId",
            principalTable: "Users",
            principalColumn: "Id",
            onDelete: ReferentialAction.Cascade);

        migrationBuilder.AddForeignKey(
            name: "FK_Shifts_Events_EventId",
            table: "Shifts",
            column: "EventId",
            principalTable: "Events",
            principalColumn: "Id",
            onDelete: ReferentialAction.Cascade);

        migrationBuilder.AddForeignKey(
            name: "FK_VolunteerHistories_Users_UserId",
            table: "VolunteerHistories",
            column: "UserId",
            principalTable: "Users",
            principalColumn: "Id",
            onDelete: ReferentialAction.Cascade);
    }
}
