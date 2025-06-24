@IsTest
private class CurrencySymbolsTest {

    @IsTest
    static void testGetSymbol_ValidUpperCase() {
        System.assertEquals('$', CurrencySymbols.getSymbol('USD'), 'USD должен вернуть $');
        System.assertEquals('€', CurrencySymbols.getSymbol('EUR'), 'EUR должен вернуть €');
        System.assertEquals('£', CurrencySymbols.getSymbol('GBP'), 'GBP должен вернуть £');
        System.assertEquals('¥', CurrencySymbols.getSymbol('JPY'), 'JPY должен вернуть ¥');
    }

    @IsTest
    static void testGetSymbol_ValidLowerCase() {
        System.assertEquals('$', CurrencySymbols.getSymbol('usd'), 'usd должен вернуть $');
        System.assertEquals('€', CurrencySymbols.getSymbol('eur'), 'eur должен вернуть €');
        System.assertEquals('£', CurrencySymbols.getSymbol('gbp'), 'gbp должен вернуть £');
        System.assertEquals('¥', CurrencySymbols.getSymbol('jpy'), 'jpy должен вернуть ¥');
    }

    @IsTest
    static void testGetSymbol_UnknownCode() {
        System.assertEquals('ABC ', CurrencySymbols.getSymbol('ABC'), 'Неизвестный код должен вернуть код + пробел');
        System.assertEquals('xyz ', CurrencySymbols.getSymbol('xyz'), 'Неизвестный код (нижний регистр) должен вернуть код + пробел');
    }

    @IsTest
    static void testGetSymbol_Null() {
        System.assertEquals('null ', CurrencySymbols.getSymbol(null), 'null должен вернуть "null "');
    }
}