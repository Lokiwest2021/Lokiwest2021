/**
*   Dynamic additional information form
*
*   @author mto
*   @copyright PARX
*/

public with sharing class AdditionalInformationForm {

	public static Map<DisplayType, PageReference> TEMPLATE_MAP = new Map<DisplayType, PageReference>();
	static {
		TEMPLATE_MAP.put(DisplayType.BOOLEAN, Page.LDSCheckbox);
		TEMPLATE_MAP.put(DisplayType.DATETIME, Page.LDSDateTime);
		TEMPLATE_MAP.put(DisplayType.DATE, Page.LDSDate);
		TEMPLATE_MAP.put(DisplayType.STRING, Page.LDSText);
		TEMPLATE_MAP.put(DisplayType.DOUBLE, Page.LDSText);
		TEMPLATE_MAP.put(DisplayType.PHONE, Page.LDSText);
		TEMPLATE_MAP.put(DisplayType.EMAIL, Page.LDSText);
		TEMPLATE_MAP.put(DisplayType.PICKLIST, Page.LDSPicklist);
		TEMPLATE_MAP.put(DisplayType.MULTIPICKLIST, Page.LDSMultiPicklist);
		TEMPLATE_MAP.put(DisplayType.TEXTAREA, Page.LDSText);
	}

	// concatenated html result
	public String html = '';

	private static String SECONDARY_FIELD_CSS_INDICATOR = 'additional-info-hidden-field';
	private static String UNKNOWN_VALUE_ALLOWED_INDICATOR = 'unknown-value-allowed';

	public void addElement(DisplayType elementType, String id, Object value, String label, Boolean mandatory, Boolean enabled, Integer maxLength, List<ACIOption> options, Boolean isSecondary, String aciRecordId, Boolean isUnknownValueAllowed)
	{
		PageReference page = TEMPLATE_MAP.get(elementType);
		System.debug('Page ' + page);
		if(page != null)
		{
			page.getParameters().put('id', id);
			page.getParameters().put('value', String.valueOf(value));
			page.getParameters().put('label', label);
			page.getParameters().put('mandatory', String.valueOf(mandatory));
			page.getParameters().put('enabled', String.valueOf(enabled));
			page.getParameters().put('maxLength', String.valueOf(maxLength));

			//dme : DE442/PARXIMPL-9099 : Reduce the number of characters placed within the URL
			if (DisplayType.MULTIPICKLIST == elementType || DisplayType.PICKLIST == elementType)
			{
				page.getParameters().put('aciRecordId', String.valueOf(aciRecordId));
			}
			else
			{
				page.getParameters().put('options', JSON.serialize(options));
			}

			page.getParameters().put('apexDataType', String.valueOf(elementType));

			List<String> classes = new List<String>();
			if (isSecondary == true)
			{
				classes.add(SECONDARY_FIELD_CSS_INDICATOR);
			}

			//dch: PARXIMPL-3114: check if we need to render a supporting field
			if (mandatory && isUnknownValueAllowed) {
				classes.add(UNKNOWN_VALUE_ALLOWED_INDICATOR);
			}

			if (!classes.isEmpty())
			{
				page.getParameters().put('classes', String.join(classes, ' '));
			}

			if(!Test.isrunningtest()) {
				this.html += page.getContent().toString();
			}
		}
	}
}