using Amazon.Lambda.Core;
using Amazon.Lambda.RuntimeSupport;
using Amazon.Lambda.Serialization.SystemTextJson;
using PetsTrading.LifecycleLambda.Services;

// Use the generated serializer for low-overhead deserialization.
[assembly: LambdaSerializer(typeof(DefaultLambdaJsonSerializer))]

namespace PetsTrading.LifecycleLambda;

/// <summary>
/// AWS Lambda entry point for the Lifecycle Engine.
/// Triggered every 60 seconds by an EventBridge Scheduler rule.
/// Applies health/desirability variance, recalculates intrinsic values,
/// and refreshes cached age and is_expired on all pet instances.
/// No events are published after a tick — the frontend polls for updated data (ADR-017).
/// </summary>
public sealed class Function
{
    private readonly VarianceEngine _varianceEngine;
    private readonly ValuationCalculator _valuationCalculator;

    /// <summary>Initialises services. Called once during Lambda container warm-up.</summary>
    public Function()
    {
        _varianceEngine = new VarianceEngine();
        _valuationCalculator = new ValuationCalculator();
    }

    /// <summary>
    /// Lambda handler invoked by EventBridge Scheduler.
    /// Processes a full lifecycle tick: variance -> valuation -> DB write.
    /// </summary>
    /// <param name="input">EventBridge Scheduler payload (unused; tick is time-driven).</param>
    /// <param name="context">Lambda execution context for logging and remaining time.</param>
    public async Task FunctionHandlerAsync(object? input, ILambdaContext context)
    {
        context.Logger.LogInformation("Lifecycle tick started at {UtcNow}", DateTime.UtcNow);

        // TODO (later story): load all pets from PostgreSQL via PetRepository
        // TODO: apply variance via _varianceEngine
        // TODO: recalculate values via _valuationCalculator
        // TODO: batch-write updated pets back to PostgreSQL

        context.Logger.LogInformation("Lifecycle tick completed.");

        await Task.CompletedTask;
    }

    /// <summary>
    /// Bootstrap entry point for Lambda container image execution.
    /// Registers the handler and starts the Lambda runtime loop.
    /// </summary>
    private static async Task Main()
    {
        var function = new Function();
        await LambdaBootstrapBuilder
            .Create(function.FunctionHandlerAsync, new DefaultLambdaJsonSerializer())
            .Build()
            .RunAsync();
    }
}
