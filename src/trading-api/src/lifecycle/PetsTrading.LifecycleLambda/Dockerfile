# ── Stage 1: Build & Publish ──────────────────────────────────────────────────
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Copy project file first to leverage Docker layer caching.
COPY src/lifecycle/PetsTrading.LifecycleLambda/PetsTrading.LifecycleLambda.csproj src/lifecycle/PetsTrading.LifecycleLambda/
COPY PetsTrading.sln .

RUN dotnet restore src/lifecycle/PetsTrading.LifecycleLambda/PetsTrading.LifecycleLambda.csproj

# Copy remaining source and publish in Release configuration.
COPY . .
RUN dotnet publish src/lifecycle/PetsTrading.LifecycleLambda/PetsTrading.LifecycleLambda.csproj \
    --configuration Release \
    --no-restore \
    --output /app/publish

# ── Stage 2: Lambda Runtime ───────────────────────────────────────────────────
# Use the official AWS Lambda base image for .NET 10 container image deployments.
FROM public.ecr.aws/lambda/dotnet:10 AS runtime

# Copy published output from the build stage.
COPY --from=build /app/publish ${LAMBDA_TASK_ROOT}

# The handler is the fully-qualified method name: Assembly::Namespace.Class::Method
CMD ["PetsTrading.LifecycleLambda::PetsTrading.LifecycleLambda.Function::FunctionHandlerAsync"]
