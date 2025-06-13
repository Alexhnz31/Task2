import { LightningElement, wire, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAccountOpportunities from '@salesforce/apex/SalesStatisticsController.getAccountOpportunities';
import getOpportunityProducts from '@salesforce/apex/SalesStatisticsController.getOpportunityProducts';

const CONSTANTS = {
    EMPTY_STRING: '',
    URL_PREFIX: '/',
    DATETYPE: {
        YEAR: 'numeric',
        MONTH: 'long',
        DAY: '2-digit'
    },
    COLUMN_TYPES: {
        URL: 'url',
        DATE: 'date',
        CURRENCY: 'currency',
        BUTTON: 'button',
        TEXT: 'text',
        NUMBER: 'number'
    },
    LABELS: {
        ERROR_LOADING_PRODUCTS: 'Error loading products',
        GENERIC_ERROR: 'An error occurred while loading products',
        ERROR_PREFIX: 'Error:',
        OPPORTUNITY_NAME: 'Opportunity Name',
        CREATED_DATE: 'Created Date',
        CLOSE_DATE: 'Close Date',
        AMOUNT: 'Amount',
        VIEW_PRODUCTS: 'View Products',
        PRODUCT: 'Product',
        QUANTITY: 'Quantity',
        TOTAL_PRICE: 'Total Price'
    },
    FIELD_NAMES: {
        NAME_URL: 'nameUrl',
        NAME: 'name',
        CREATED_DATE: 'createdDate',
        CLOSE_DATE: 'closeDate',
        AMOUNT: 'amount',
        PRODUCT_NAME: 'productName',
        QUANTITY: 'quantity',
        TOTAL_PRICE: 'totalPrice'
    },
    VARIANTS: {
        BRAND: 'brand',
        ERROR: 'error'
    },
    ICONS: {
        PRODUCT: 'utility:product'
    },
    ACTIONS: {
        VIEW_PRODUCTS: 'view_products'
    },
    TARGET: {
        BLANK: '_blank'
    }
};

export default class SalesStatistics extends NavigationMixin(LightningElement) {
    @api recordId;
    @api flexipageRegionWidth;

    loading = false;
    error;
    totalRecords = 0;
    currentPage = 1;
    pageSize = 10;
    searchTerm = CONSTANTS.EMPTY_STRING;
    minAmount = null;
    isModalOpen = false;
    selectedOpportunityName = CONSTANTS.EMPTY_STRING;
    opportunityProducts = [];
    accounts = [];

    columns = [
        {
            label: CONSTANTS.LABELS.OPPORTUNITY_NAME,
            fieldName: CONSTANTS.FIELD_NAMES.NAME_URL,
            type: CONSTANTS.COLUMN_TYPES.URL,
            typeAttributes: {
                label: { fieldName: CONSTANTS.FIELD_NAMES.NAME },
                target: CONSTANTS.TARGET.BLANK
            }
        },
        {
            label: CONSTANTS.LABELS.CREATED_DATE,
            fieldName: CONSTANTS.FIELD_NAMES.CREATED_DATE,
            type: CONSTANTS.COLUMN_TYPES.DATE,
            typeAttributes: {
                year: CONSTANTS.DATETYPE.YEAR,
                month: CONSTANTS.DATETYPE.MONTH,
                day: CONSTANTS.DATETYPE.DAY
            }
        },
        {
            label: CONSTANTS.LABELS.CLOSE_DATE,
            fieldName: CONSTANTS.FIELD_NAMES.CLOSE_DATE,
            type: CONSTANTS.COLUMN_TYPES.DATE,
            typeAttributes: {
                year: CONSTANTS.DATETYPE.YEAR,
                month: CONSTANTS.DATETYPE.MONTH,
                day: CONSTANTS.DATETYPE.DAY
            }
        },
        {
            label: CONSTANTS.LABELS.AMOUNT,
            fieldName: CONSTANTS.FIELD_NAMES.AMOUNT,
            type: CONSTANTS.COLUMN_TYPES.CURRENCY
        },
        {
            type: CONSTANTS.COLUMN_TYPES.BUTTON,
            typeAttributes: {
                label: CONSTANTS.LABELS.VIEW_PRODUCTS,
                name: CONSTANTS.ACTIONS.VIEW_PRODUCTS,
                title: CONSTANTS.LABELS.VIEW_PRODUCTS,
                variant: CONSTANTS.VARIANTS.BRAND,
                iconName: CONSTANTS.ICONS.PRODUCT,
                alternativeText: CONSTANTS.LABELS.VIEW_PRODUCTS
            }
        }
    ];

    productColumns = [
        {
            label: CONSTANTS.LABELS.PRODUCT,
            fieldName: CONSTANTS.FIELD_NAMES.PRODUCT_NAME,
            type: CONSTANTS.COLUMN_TYPES.TEXT
        },
        {
            label: CONSTANTS.LABELS.QUANTITY,
            fieldName: CONSTANTS.FIELD_NAMES.QUANTITY,
            type: CONSTANTS.COLUMN_TYPES.NUMBER
        },
        {
            label: CONSTANTS.LABELS.TOTAL_PRICE,
            fieldName: CONSTANTS.FIELD_NAMES.TOTAL_PRICE,
            type: CONSTANTS.COLUMN_TYPES.CURRENCY
        }
    ];

    // Используем recordId как accountId для фильтрации (если нужно)
    get accountId() {
        return this.recordId || null;
    }

    @wire(getAccountOpportunities, {
        accountId: '$accountId',
        searchTerm: '$searchTerm',
        minAmount: '$minAmount',
        pageSize: '$pageSize',
        pageNumber: '$currentPage'
    })
    wiredAccounts({ error, data }) {
        if (data) {
            const formatter = new Intl.NumberFormat('ru-RU', {
                style: 'currency',
                currency: 'RUB'
            });
            this.accounts = data.accounts.map(account => ({
                ...account,
                accordionLabel: `${account.name} (Всего: ${formatter.format(account.totalAmount)})`,
                opportunities: account.opportunities.map(opp => ({
                    ...opp,
                    nameUrl: CONSTANTS.URL_PREFIX + opp.id
                }))
            }));
            this.totalRecords = data.totalRecords;
            this.error = undefined;
            this.loading = false;
        } else if (error) {
            this.handleError(error);
            this.loading = false;
        }
    }

    // Ставим loading = true при начале нового запроса
    handleSearchChange(event) {
        this.loading = true;
        this.searchTerm = event.target.value;
        this.currentPage = 1;
    }

    handleAmountChange(event) {
        this.loading = true;
        this.minAmount = event.target.value ? parseFloat(event.target.value) : null;
        this.currentPage = 1;
    }

    handleNext() {
        if (this.currentPage < this.totalPages) {
            this.loading = true;
            this.currentPage += 1;
        }
    }

    handlePrevious() {
        if (this.currentPage > 1) {
            this.loading = true;
            this.currentPage -= 1;
        }
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === CONSTANTS.ACTIONS.VIEW_PRODUCTS) {
            this.loading = true;
            this.selectedOpportunityName = row.name;

            getOpportunityProducts({ opportunityId: row.id })
                .then(result => {
                    this.opportunityProducts = result;
                    this.isModalOpen = true;
                })
                .catch(error => {
                    console.error(`${CONSTANTS.LABELS.ERROR_PREFIX}`, error);
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: CONSTANTS.LABELS.ERROR_LOADING_PRODUCTS,
                            message: error.body?.message || CONSTANTS.LABELS.GENERIC_ERROR,
                            variant: CONSTANTS.VARIANTS.ERROR
                        })
                    );
                })
                .finally(() => {
                    this.loading = false;
                });
        }
    }

    closeModal() {
        this.isModalOpen = false;
        this.selectedOpportunityName = CONSTANTS.EMPTY_STRING;
        this.opportunityProducts = [];
    }

    get isRecordPage() {
        return !!this.recordId;
    }

    get totalPages() {
        return Math.ceil(this.totalRecords / this.pageSize);
    }

    get isFirstPage() {
        return this.currentPage === 1;
    }

    get isLastPage() {
        return this.currentPage >= this.totalPages;
    }

    get hasAccounts() {
        return Array.isArray(this.accounts) && this.accounts.length > 0;
    }

    handleError(error) {
        console.error(`${CONSTANTS.LABELS.ERROR_PREFIX}`, error);
        this.error = error;
        this.accounts = [];
        this.loading = false;
    }

    connectedCallback() {
        this.loading = true;
    }
}
