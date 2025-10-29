import ballerina/test;

// Tests for print utility functions
// Note: These functions are tested mainly for execution without errors
// since they produce side effects (console output) that are hard to capture in unit tests
// In a real-world scenario, you might want to:
// 1. Mock io:println to capture output
// 2. Use integration tests with output redirection
// 3. Test the formatting logic separately from the printing

@test:Config
function testPrintInfo() {
    // Verifies function executes without throwing errors
    printInfo("Test info message");
}

@test:Config
function testPrintWarning() {
    printWarning("Test warning message");
}

@test:Config
function testPrintError() {
    error testError = error("Test error message");
    printError(testError);
}

@test:Config
function testPrintErrorWithCause() {
    // Verifies error cause chain is handled
    error rootCause = error("Root cause");
    error wrappedError = error("Wrapped error", rootCause);
    printError(wrappedError);
}

@test:Config
function testPrintErrorWithMultipleCauses() {
    // Verifies multiple levels of error causes are handled
    error cause1 = error("First cause");
    error cause2 = error("Second cause", cause1);
    error mainError = error("Main error", cause2);
    printError(mainError);
}

@test:Config
function testPrintSuccess() {
    printSuccess("Test success message");
}

@test:Config
function testPrintProgress() {
    printProgress("Test progress message");
}

@test:Config
function testPrintStats() {
    printStats("Test stats message");
}

@test:Config
function testPrintInfoWithSpecialCharacters() {
    // Verifies special characters don't cause errors
    printInfo("Test with special chars: !@#$%^&*()");
}

@test:Config
function testPrintInfoWithEmptyString() {
    printInfo("");
}

@test:Config
function testPrintInfoWithLongMessage() {
    string longMessage = "This is a very long message that contains many characters and goes on and on to test how the print function handles long strings with lots of content including numbers 123456789 and special characters !@#$%";
    printInfo(longMessage);
}

@test:Config
function testPrintWarningWithNewlines() {
    printWarning("Line 1\nLine 2\nLine 3");
}

@test:Config
function testPrintSuccessWithUnicode() {
    printSuccess("Test with unicode: ✓ ✗ ★ ♠ ♣");
}

@test:Config
function testPrintStatsWithNumbers() {
    printStats("Processed 1,234,567 records in 45.6 seconds");
}

@test:Config
function testPrintErrorWithEmptyMessage() {
    error testError = error("");
    printError(testError);
}

@test:Config
function testPrintProgressWithPercentage() {
    printProgress("Progress: 75% complete");
}

@test:Config
function testPrintMultipleMessages() {
    // Verifies multiple rapid print calls don't cause issues
    printInfo("Message 1");
    printWarning("Message 2");
    printSuccess("Message 3");
    printProgress("Message 4");
    printStats("Message 5");
}

@test:Config
function testPrintInfoWithStringInterpolation() {
    int count = 42;
    string name = "test";
    printInfo(string `Processing ${count} items for ${name}`);
}

@test:Config
function testPrintStatsWithComplexFormatting() {
    printStats(string `Total: ${100}, Success: ${95}, Failed: ${5}, Rate: ${95.0}%`);
}
