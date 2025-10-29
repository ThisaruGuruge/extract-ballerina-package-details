import ballerina/test;

@test:Config
function testIsValidISODateValid() {
    boolean result = isValidISODate("2024-01-15");
    test:assertTrue(result, "Should accept valid ISO date");
}

@test:Config
function testIsValidISODateValidLeapYear() {
    boolean result = isValidISODate("2024-02-29");
    test:assertTrue(result, "Should accept valid leap year date");
}

@test:Config
function testIsValidISODateInvalidFormat() {
    boolean result = isValidISODate("2024/01/15");
    test:assertFalse(result, "Should reject date with slashes");
}

@test:Config
function testIsValidISODateInvalidLength() {
    boolean result = isValidISODate("2024-1-5");
    test:assertFalse(result, "Should reject date without leading zeros");
}

@test:Config
function testIsValidISODateInvalidMonth() {
    boolean result = isValidISODate("2024-13-01");
    test:assertFalse(result, "Should reject month > 12");
}

@test:Config
function testIsValidISODateInvalidDay() {
    boolean result = isValidISODate("2024-01-32");
    test:assertFalse(result, "Should reject day > 31");
}

@test:Config
function testIsValidISODateInvalidYear() {
    boolean result = isValidISODate("1999-01-01");
    test:assertFalse(result, "Should reject year < 2000");
}

@test:Config
function testIsValidISODateNonNumeric() {
    boolean result = isValidISODate("abcd-ef-gh");
    test:assertFalse(result, "Should reject non-numeric values");
}

@test:Config
function testIsValidISODateEmpty() {
    boolean result = isValidISODate("");
    test:assertFalse(result, "Should reject empty string");
}

@test:Config
function testIsValidISODateBoundaryYears() {
    test:assertTrue(isValidISODate("2000-01-01"), "Should accept year 2000");
    test:assertTrue(isValidISODate("3000-12-31"), "Should accept year 3000");
    test:assertFalse(isValidISODate("3001-01-01"), "Should reject year > 3000");
}
