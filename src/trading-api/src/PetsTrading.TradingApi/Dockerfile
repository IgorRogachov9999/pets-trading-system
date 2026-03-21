# ── Stage 1: Build & Publish ──────────────────────────────────────────────────
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Copy project files first to leverage Docker layer caching.
# NuGet restore only re-runs when .csproj files change, not on every code change.
COPY src/PetsTrading.Domain/PetsTrading.Domain.csproj src/PetsTrading.Domain/
COPY src/PetsTrading.Application/PetsTrading.Application.csproj src/PetsTrading.Application/
COPY src/PetsTrading.Infrastructure/PetsTrading.Infrastructure.csproj src/PetsTrading.Infrastructure/
COPY src/PetsTrading.TradingApi/PetsTrading.TradingApi.csproj src/PetsTrading.TradingApi/
COPY PetsTrading.sln .

RUN dotnet restore src/PetsTrading.TradingApi/PetsTrading.TradingApi.csproj

# Copy remaining source and publish in Release configuration.
COPY . .
RUN dotnet publish src/PetsTrading.TradingApi/PetsTrading.TradingApi.csproj \
    --configuration Release \
    --no-restore \
    --output /app/publish

# ── Stage 2: Runtime ──────────────────────────────────────────────────────────
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app

# Run as a non-root user for least-privilege security (ECS Fargate requirement).
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser
USER appuser

# Copy published output from the build stage.
COPY --from=build /app/publish .

# ALB terminates TLS; the container listens on plain HTTP 8080.
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

ENTRYPOINT ["dotnet", "PetsTrading.TradingApi.dll"]
