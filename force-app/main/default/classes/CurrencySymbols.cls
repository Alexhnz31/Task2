public class CurrencySymbols {
    private static final Map<String, String> SYMBOLS = new Map<String, String>{
        'USD' => '$',
        'EUR' => '€',
        'GBP' => '£',
        'JPY' => '¥'
    };

    public static String getSymbol(String isoCode) {
        return SYMBOLS.get(isoCode) ?? isoCode + ' ';
    }
}