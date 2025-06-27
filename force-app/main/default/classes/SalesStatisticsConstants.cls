public class SalesStatisticsConstants {
    public static final String ERROR_PREFIX = 'Ошибка Apex: ';
    public static final String ERROR_NO_OPP_ID = 'Не указан ID сделки';
    public static final String SLASH = '/';
    public static final String SELECT_ACCOUNT = 'SELECT Id, Name, (SELECT Id, Name, Amount, StageName, CloseDate, CreatedDate FROM Opportunities WHERE IsClosed = true) FROM Account';
    public static final String SELECT_COUNT = 'SELECT COUNT() FROM Account';
    public static final String WHERE_STR = ' WHERE ';
    public static final String AND_STR = ' AND ';
    public static final String ORDER_BY = ' ORDER BY Name LIMIT :pageSize OFFSET :offset';
    public static final String ID_EQ = 'Id = :accountId';
    public static final String NAME_LIKE = 'Name LIKE :search';
    public static final String PERCENT = '%';
}