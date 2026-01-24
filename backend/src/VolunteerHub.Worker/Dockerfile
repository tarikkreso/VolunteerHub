# VolunteerHub Worker Service
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy project files
COPY ["src/VolunteerHub.Worker/VolunteerHub.Worker.csproj", "src/VolunteerHub.Worker/"]
COPY ["src/VolunteerHub.Application/VolunteerHub.Application.csproj", "src/VolunteerHub.Application/"]
COPY ["src/VolunteerHub.Infrastructure/VolunteerHub.Infrastructure.csproj", "src/VolunteerHub.Infrastructure/"]
COPY ["src/VolunteerHub.Domain/VolunteerHub.Domain.csproj", "src/VolunteerHub.Domain/"]
COPY ["src/VolunteerHub.Shared/VolunteerHub.Shared.csproj", "src/VolunteerHub.Shared/"]

# Restore packages
RUN dotnet restore "src/VolunteerHub.Worker/VolunteerHub.Worker.csproj"

# Copy source code
COPY . .

# Build
WORKDIR "/src/src/VolunteerHub.Worker"
RUN dotnet build "VolunteerHub.Worker.csproj" -c Release -o /app/build

# Publish
FROM build AS publish
RUN dotnet publish "VolunteerHub.Worker.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Final image
FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "VolunteerHub.Worker.dll"]
