/**
*   Service Class for the Additional Information.
*
*   @author mtt, kiv, ach, dvo
*   @copyright PARX
*/
public with sharing class AdditionalInformationService
{
	//@kiv: US347
	public static final String ACI_PREFIX = 'ACI_';
	//dme : PARXIMPL-1464 : ACI fields can have 'ACI_' or 'CC_ACI_' prefix
	public static final String CC_ACI_PREFIX = 'CC_ACI_';

	// dvo : PARXIMPL-3083 : Contact Type should be treated as ACI field
	public static final Set<String> ACI_FIELDS_WITHOUT_PREFIX = new Set<String>
	{
			'TypeOfContact__c'
	};

	public static final String ACI_AVAILABLE_VALUE_SEPARATOR = '\n';

	public static final String MERGE_FIELD_TEMPLATE = '<br/>{0} : {1}';

	private MetadataHelperInterface metadataHelper = new MetadataHelper();

	private static Map<Id, AdditionalCaseInformation__c> cacheadditionalCaseInfoMap = new Map<Id, AdditionalCaseInformation__c>();

	public AdditionalInformationService(){}

	public AdditionalInformationService(MetadataHelperInterface metadataHelper)
	{
		this.metadataHelper = metadataHelper;
	}

	public Boolean hasAdditionalInformationFields(String categoryId)
	{
		AdditionalCaseField__c[] fields = [
											  SELECT Id, Name, CaseFieldAPIName__c, CaseFieldValue__c, CaseFieldValueTranslation__c, Mandatory__c
											  FROM AdditionalCaseField__c
											  WHERE AdditionalCaseInformation__r.Category__c = :categoryId
													  AND AdditionalCaseInformation__r.ServiceCountryCode__c = :UserService.getCountryCode()
										  ];

		return fields.size() > 0;
	}


	public List<ACIOption> getOptionsForField(AdditionalCaseField__c field, String savedValuesStr)
	{
		LabelsForPicklistWrapper labelsWrapper = metadataHelper.getLabelsForPicklist(field, true, savedValuesStr);
		Map<String, String> labelStrings = labelsWrapper.labelsForPicklist;
		//System.debug(loggingLevel.WARN, '....metadataHelper.getLabelsForPicklist: ' + metadataHelper.getLabelsForPicklist2(field, true, savedValuesStr));
		List<ACIOption> options = new List<ACIOption>();
		Set<String> savedValues = new Set<String>(savedValuesStr.split(';'));
		for (String sv : savedValues)
		{
			sv = sv.trim();
		}

		integer index = 0;
		for (String label : labelStrings.keySet())
		{
			options.add(new ACIOption(label, labelStrings.get(label), savedValues.contains(label), field.CaseFieldAPIName__c + '[' + index + ']', labelsWrapper.isExtraOption && label == savedValuesStr));
			index++;
		}

		return options;
	}

	public AdditionalCaseField__c selectField(String id)
	{
		List<AdditionalCaseField__c> caseFields = [SELECT Id, CaseFieldValue__c, CaseFieldAPIName__c FROM AdditionalCaseField__c WHERE Id = :id];
		if (caseFields != null && caseFields.size() == 1)
		{
			return caseFields[0];
		}

		return null;
	}

	public List<SelectOption> getSavedPicklistValues(String id)
	{
		List<SelectOption> savedValues = new List<SelectOption>();
		AdditionalCaseField__c caseField = selectField(id);

		System.debug('saved caseField.CaseFieldValue__c: ' + caseField.CaseFieldValue__c);
		// Add saved values to the right select
		if (caseField != null && String.isNotEmpty(caseField.CaseFieldValue__c))
		{
			for (String value : caseField.CaseFieldValue__c.split('\n'))
			{
				//TODO: it has to display labels!!!
				savedValues.add(new SelectOption(value, value));
			}
		}

		return savedValues;
	}

	/**
	*    @description US210. If email AND OR mobile phone are already defined at Contact Data the informations have to be pre-filled at the email and phone fields automatically.
	*                        Otherwise the fields are reseted.
	*/
	public void prefillPreferredCommunicationChannel(Case contextCase, String aciCategoryId)
	{
		contextCase.ACI_ReservationEmail__c = null;
		contextCase.ACI_ReservationMobilePhone__c = null;
		if (contextCase != null && contextCase.Contact != null && String.isNotBlank(aciCategoryId)  &&
				(String.isNotBlank(contextCase.Contact.Email) || String.isNotBlank(contextCase.Contact.MobilePhone)))
		{
			List<Category__c> categories = (List<Category__c>)DatabaseUtils.getRelatedSobjects(
											   'Category__c',
											   new List<String> {'Name'},
											   new Set<Id> {Id.valueOf(aciCategoryId)}
										   );

			if (!categories.isEmpty())
			{
				Category__c contextCategory = categories.get(0);

				String qualifier = 'ProductReservationCategoryConfig';
				String targetCategoryName = CustomMetadataTypeService.findByQualifier(qualifier);

				if (contextCategory.Name == targetCategoryName)
				{
					contextCase.ACI_ReservationEmail__c = contextCase.Contact.Email;
					contextCase.ACI_ReservationMobilePhone__c = contextCase.Contact.MobilePhone;

					if (String.isNotBlank(contextCase.Id))
					{
						update contextCase;
					}
				}
			}
		}
	}

	/**
	 *	@description US347 Returns true if the api name beggins with 'ACI_' or 'CC_ACI_'(PARXIMPL-1464)
	 *	@author kiv, dme, dvo
	 *	@jira US347, PARXIMPL-3083
	 *
	 * 	@return Boolean Value that is true if given field is ACI and false if not
	 */
	public static Boolean isACIField(String apiName)
	{
		return String.isNotBlank(apiName)
			? (apiName.contains('.')
			   ? (apiName.substringAfterLast('.').startsWithIgnoreCase(AdditionalInformationService.ACI_PREFIX) || apiName.substringAfterLast('.').startsWithIgnoreCase(AdditionalInformationService.CC_ACI_PREFIX) || ACI_FIELDS_WITHOUT_PREFIX.contains(apiName))
			   : (apiName.startsWithIgnoreCase(AdditionalInformationService.ACI_PREFIX) || apiName.startsWithIgnoreCase(AdditionalInformationService.CC_ACI_PREFIX) || ACI_FIELDS_WITHOUT_PREFIX.contains(apiName)))
			: false;
	}

	/*
	*	@author kiv
	*	@description US347
	*/
	public class AdditionalFieldsConfig
	{
		public Set<String> serviceCountryCodes {get; set;}
		public Set<String> categoryIds {get; set;}

		private Map<String, Map<String, AdditionalCaseField__c>> additionalFieldsMap;
		private Map<String, AdditionalCaseInformation__c> addtionalInfoMap;

		public AdditionalFieldsConfig(Set<String> serviceCountryCodes, Set<String> categoryIds)
		{
			this.serviceCountryCodes = serviceCountryCodes;
			this.categoryIds = categoryIds;
			this.additionalFieldsMap = new Map<String, Map<String, AdditionalCaseField__c>>();
		}

		/**
		* US347 Returns the map: key = CaseFieldAPIName__c, value = AdditionalCaseField__c based on Service Country Code and Category
		*/
		public Map<String, AdditionalCaseField__c> getAdditionalFieldsMapByCountryAndCategory(String sCountryCode, Id categoryId)
		{
			String mapKey = sCountryCode + categoryId;
			if (this.addtionalInfoMap != null && !this.addtionalInfoMap.containsKey( mapkey ))
			{
				return new Map<String, AdditionalCaseField__c>();
			}

			if (this.additionalFieldsMap != null && this.additionalFieldsMap.containsKey( mapKey ))
			{
				return this.additionalFieldsMap.get( mapKey );
			}

			if (this.addtionalInfoMap == null)
			{
				this.addtionalInfoMap = new Map<String, AdditionalCaseInformation__c>();
				this.additionalFieldsMap = new Map<String, Map<String, AdditionalCaseField__c>>();

				List<AdditionalCaseInformation__c> caseInformation = getAdditionalInfoCountriesSpecified();
				System.debug('***** caseInformation ' + caseInformation);
				for (AdditionalCaseInformation__c info : caseInformation)
				{
					this.addtionalInfoMap.put(info.ServiceCountryCode__c + info.Category__c, info);
				}
			}

			if (!this.additionalFieldsMap.containsKey( mapKey ) && this.addtionalInfoMap.containsKey( mapKey ))
			{
				this.additionalFieldsMap.put( mapKey, new Map<String, AdditionalCaseField__c>());

				AdditionalCaseInformation__c info = this.addtionalInfoMap.get(mapKey);
				if (info.Additional_Case_Fields__r != null)
				{
					for (AdditionalCaseField__c addField : info.Additional_Case_Fields__r)
					{
						this.additionalFieldsMap.get(mapKey).put(addField.CaseFieldAPIName__c, addField);
					}
				}
			}
			return this.additionalFieldsMap.get(mapKey) != null ? this.additionalFieldsMap.get(mapKey) : new Map<String, AdditionalCaseField__c>();
		}

		/*
		*   It retrieves all the additional fields FROM DB for specified counries.
		*/
		private List<AdditionalCaseInformation__c> getAdditionalInfoCountriesSpecified()
		{
			return AdditionalInformationService.getAdditionalInfo(this.serviceCountryCodes, this.categoryIds);
		}

		/*
		*	@author kiv
		*	@description US347 Returns set of aci service partner relevant fields
		*/
		public Set<String> filterACISPRelevantFields(Map<String, AdditionalCaseField__c> aciFieldsMap)
		{
			Set<String> spRelevantFields = new Set<String>();
			for (String theACI : aciFieldsMap.keySet())
			{
				if (AdditionalInformationService.isACIField(theACI) && aciFieldsMap.get(theACI).ServicePartnerRelevant__c)
				{
					String fieldApiName = theACI.contains('.') ? theACI.substringAfterLast('.') : theACI;
					spRelevantFields.add(fieldApiName.toLowerCase());
				}
			}
			return spRelevantFields;
		}

		/**
		* US347 Returns set of aci service partner relevant fields
		*/
		public Set<String> getACISPRelevantFields(String sCountryCode, Id categoryId)
		{
			Map<String, AdditionalCaseField__c> mapd = this.getAdditionalFieldsMapByCountryAndCategory(sCountryCode, categoryId);
			return this.filterACISPRelevantFields(mapd);
		}
	}

	/*
	*   It retrieves all the additional fields FROM DB.
	*	ach: Refactored in scope of "PARXIMPL-3525 UAT: Apex Script Error - Too many SOQL queries"
	*/
	public static List<AdditionalCaseInformation__c> getAdditionalInfo(Set<String> sCounryCodes, Set<String> categoryIds)
	{
		List<AdditionalCaseInformation__c> result = new List<AdditionalCaseInformation__c>();
		if (!cacheadditionalCaseInfoMap.isEmpty() && categoryIds != null && !categoryIds.isEmpty())
		{
			//ach PARXIMPL-3525 UAT: Apex Script Error - Too many SOQL queries
			for (Id categoryId : categoryIds)
			{
				if (cacheadditionalCaseInfoMap.containsKey(categoryId))
				{
					if (sCounryCodes != null && !sCounryCodes.isEmpty() && sCounryCodes.contains(cacheadditionalCaseInfoMap.get(categoryId).ServiceCountryCode__c))
					result.add(cacheadditionalCaseInfoMap.get(categoryId));
				}
			}
			if (result.size() == categoryIds.size())
			{
				//ach PARXIMPL-3525 : we get everything from the cache
				return result;
			}
		}
		String query = ' SELECT Id, Category__c, ServiceCountryCode__c, (SELECT Id, CaseFieldAPIName__c, ServicePartnerRelevant__c FROM Additional_Case_Fields__r)';
		query += ' FROM AdditionalCaseInformation__c';
		query += ' WHERE ServiceCountryCode__c != null AND Category__c != null ';
		if (sCounryCodes != null && !sCounryCodes.isEmpty())
		{
			query += ' AND ServiceCountryCode__c IN: sCounryCodes ';
		}
		if (categoryIds != null && !categoryIds.isEmpty())
		{
			query += ' AND Category__c IN: categoryIds ';
		}
		query += ' LIMIT ' + (Limits.getLimitQueryRows() - Limits.getQueryRows());
		System.debug(' getAdditionalFields query *** ' + query);
		result =  (List<AdditionalCaseInformation__c>)Database.query(query);
		cacheadditionalCaseInfoMap = new Map<Id, AdditionalCaseInformation__c>(result);
		return result;
	}

	//dme: PARXIMPL-374 Just refactoring
	public static List<AdditionalCaseField__c> loadCaseFields(String serviceCountryCode, String aciCategoryId, Case theCase)
	{
		if (serviceCountryCode == null)
		{
			return new List<AdditionalCaseField__c>();
		}
		return AdditionalInformationService.retrieveAdditionalFields(serviceCountryCode, aciCategoryId, new MetadataHelper(), theCase);
	}


	/*
	*	@author ?, ach
	*	@description Retrieve Additional fields from DB based on params on user info (language, profile)
	*/
	public static List<AdditionalCaseField__c> retrieveAdditionalFields(String serviceCountryCode, String aciCategoryId, MetadataHelperInterface metadataHelper, Case newCase)
	{
		List<AdditionalCaseField__c> fields = new List<AdditionalCaseField__c>();
		Set<String> fieldSets = new Set<String>{
				'Id' , 'Name', 'CaseFieldAPIName__c', 'CaseFieldValue__c', 'CaseFieldValueTranslation__c', 'Mandatory__c', 'CC_UnknownValueAllowed__c ', 'Order__c', 'IsCritical__c',
				'IsCriticism__c', 'MerchandiseGroup__c', 'MerchandiseSubGroup__c', 'AvailableForProfiles__c', 'AdditionalCaseInformation__r.Category__c', 'IsHidden__c',
				'CC_IsControllingParent__c', 'CC_ControllingParent__c', 'CC_ControllingParentValue__c', 'CC_IsControlledByParent__c', 'CC_ControllingPurchaseChannel__c'
		};

		// PARXIMPL-4828 : mtt : select Merchandise Sub Group to be used to filter fields
		String merchandiseSubGroupId = '';
		String merchandiseSubGroupCondition = '';
		List<Case> cases = (List<Case>)DatabaseUtils.getRelatedSobjects('Case', new List<String>{'Product.MerchandiseSubGroupLookup__c'}, new Set<Id>{ newCase.Id });
		if(cases != null && cases.size() == 1)
		{
			merchandiseSubGroupId = cases.get(0).Product.MerchandiseSubGroupLookup__c;
			if(String.isNotEmpty(merchandiseSubGroupId))
			{
				merchandiseSubGroupCondition = ' AND (MerchandiseSubGroup__c = null OR MerchandiseSubGroup__c = :merchandiseSubGroupId) ';
			}
		}

		Language__c[] langs = [SELECT Name, LocaleCode__c FROM Language__c WHERE LocaleCode__c = :UserInfo.getLocale().substringAfter('_')];

		if (langs != null && langs.size() == 1)
		{
			String localeCode = String.isNotEmpty(langs[0].LocaleCode__c) ? langs[0].LocaleCode__c : '';
			fields = Database.query('SELECT ' + String.join(new List<String>(fieldSets), ',') +
						' FROM AdditionalCaseField__c ' +
						'WHERE AdditionalCaseInformation__r.Category__c = :aciCategoryId ' +
						'AND AdditionalCaseInformation__r.ServiceCountryCode__c = :serviceCountryCode ' +
						'AND AdditionalCaseInformation__r.Language__r.LocaleCode__c = :localeCode ' +
						'AND CaseFieldAPIName__c != NULL ' +
					  	merchandiseSubGroupCondition +
						'ORDER BY IsHidden__c, Order__c ASC NULLS LAST');
		}

		//if nothing found retry without language
		if (fields.size() == 0)
		{
			fields = Database.query('SELECT ' + String.join(new List<String>(fieldSets), ',') +
						' FROM AdditionalCaseField__c ' +
						'WHERE AdditionalCaseInformation__r.Category__c = :aciCategoryId ' +
						'AND AdditionalCaseInformation__r.ServiceCountryCode__c = :serviceCountryCode ' +
						'AND CaseFieldAPIName__c != NULL ' +
						merchandiseSubGroupCondition +
						'ORDER BY IsHidden__c, Order__c ASC NULLS LAST');
		}

		// DHE: added at 19.01.2017
		fields = removeFieldsNotSelectedForProfile(fields);

		// check if field still exists because it might have been deleted
		for (Integer i = fields.size() - 1; i >= 0; i--)
		{
			//validate that the field still exists on case, it might have been deleted
			if (!isFieldFieldValid(fields[i], metadataHelper, newCase))
			{
				//Remove field from fields
				fields.remove(i);
			}
		}

		return fields;
	}

	//dme: PARXIMPL-374 Return Label : Value format for related to case ACI fields
	public static String getCaseFieldsWithValuesAsText(String mergeFieldsToken, String serviceCountryCode, Case theCase, Set<String> fieldsToDelete)
	{
		String result = '';
		Map<String,Schema.SObjectField> objectFields = ReflectionUtils.getSobjectFields('Case');
		Case caseRecord = theCase;

		List<AdditionalCaseField__c> aciFields = loadCaseFields(serviceCountryCode, theCase.Category__c, theCase);
		//isk PARXIMPL-14292(issue 5) If no ACI fields are filled (e.g. if current topic is set - category 3.3.2 for ESP) no warning messages are displayed for the merge fields {!FilledConsolidatedACIs} and {!AllConsolidatedACIs}
		if (aciFields.isEmpty())
		{
			return result;
		}
		String additionalFields = '';
		Set<String> aciFieldSet = new Set<String>();
		for (AdditionalCaseField__c field : aciFields)
		{
			String caseFieldAPI = field.CaseFieldAPIName__c.contains('.') ? field.CaseFieldAPIName__c.replaceAll('^.*\\.', '') : field.CaseFieldAPIName__c;
			if (!aciFieldSet.contains(caseFieldAPI))
			{
				if (objectFields.containsKey(caseFieldAPI) && (objectFields.get(caseFieldAPI).getDescribe().getType() == DisplayType.PICKLIST ||
						objectFields.get(caseFieldAPI).getDescribe().getType() == DisplayType.MULTIPICKLIST))
				{
					//ach PARXIMPL-6460, PARXIMPL-7055 Case Communication Language does not lead to correct usage of Language Labels and values for super merge fields like {!FilledConsolidatedACIs}
					//We need to translate picklists
					additionalFields += 'toLabel(' + caseFieldAPI + '),';
				} else
				{
					additionalFields += caseFieldAPI + ',';
				}
				aciFieldSet.add(caseFieldAPI);
			}
		}

		//isk: PARXIMPL-6761: output formatted value of the ACI "Best before date"
		if (additionalFields.contains('ACI_BestBeforeDate__c'))
		{
			additionalFields += 'CC_BestBeforeDateForm__c' + ',';
		}

		additionalFields = String.escapeSingleQuotes(additionalFields);
		Id caseId = theCase.Id;
		List<SObject> cases = Database.query('SELECT Id, ' +
			additionalFields.substring(0, additionalFields.length() - 1) +
			' FROM Case WHERE Id = :caseId');
		if (!cases.isEmpty())
		{
			caseRecord = (Case) cases.get(0);
		}

		Map<String, Schema.SObjectField> caseFieldMap = Schema.SObjectType.Case.fields.getMap();
		String skipNullValuesMergeTokenVariable = FieldUtils.getMergeTokenVariable(FieldUtils.FILLED_CONSOLIDATED_ACI_FIELDS);
		aciFieldSet.clear();
		for (AdditionalCaseField__c field : aciFields)
		{
			String caseFieldAPI = field.CaseFieldAPIName__c.contains('.') ? field.CaseFieldAPIName__c.replaceAll('^.*\\.', '') : field.CaseFieldAPIName__c;
			Boolean isSkipEmptyValue = skipNullValuesMergeTokenVariable.equalsIgnoreCase(mergeFieldsToken)
				&& (caseRecord.get(caseFieldAPI) == null
				|| String.isEmpty(String.valueOf(caseRecord.get(caseFieldAPI))));

			//dme : PARXIMPL-3990 : Updated transfer personal data logic
			if (isSkipEmptyValue || (!CaseSPSyncService.withPersonalData(theCase.ACI_TransferPersonalData__c) && fieldsToDelete.contains(caseFieldAPI)))
			{
				continue;
			}

			if (!aciFieldSet.contains(caseFieldAPI))
			{
				//ako : PARXIMPL-10373 : datetime and date fields should be shown in the user locale
				//isk: PARXIMPL-6761: output formatted value of the ACI "Best before date"
				String stringFieldValue = caseFieldAPI.contains('ACI_BestBeforeDate__c')
											? String.valueOf(caseRecord.get('CC_BestBeforeDateForm__c'))
											: caseFieldMap.containsKey(caseFieldAPI) && caseRecord.get(caseFieldAPI) != null && caseFieldMap.get(caseFieldAPI).getDescribe().getType() == DisplayType.DATETIME
												? String.valueOf(((Datetime)caseRecord.get(caseFieldAPI)).format())
												: caseFieldMap.containsKey(caseFieldAPI) && caseFieldMap.get(caseFieldAPI).getDescribe().getType() == DisplayType.DATE
													// npo PARXIMPL-10565: {!AllConsolidatedACIs} merge field is not replaced with values in some cases
													? (caseRecord.get(caseFieldAPI) != null ? String.valueOf(((Date) caseRecord.get(caseFieldAPI)).format()) : '')
													: String.valueOf(caseRecord.get(caseFieldAPI));

				result += String.format(MERGE_FIELD_TEMPLATE, new List<String> {Case.SObjectType.getDescribe().fields.getMap().get(caseFieldAPI).getDescribe().getLabel(), stringFieldValue});

				aciFieldSet.add(caseFieldAPI);
			}
		}
		return result;
	}


	/**
	*	@author DHE
	*	@description Removes not for the current profile selected fields from the field list.
	*/
	public static List <AdditionalCaseField__c> removeFieldsNotSelectedForProfile(List<AdditionalCaseField__c> fieldList)
	{
		String userProfileId = UserInfo.getProfileId();
		Set <AdditionalCaseField__c> fieldSet = new Set <AdditionalCaseField__c> (fieldList);

		for (AdditionalCaseField__c currentField : fieldSet)
		{
			// if the list of profiles is empty, show the field in the page --> no removing
			if (String.isBlank(currentField.AvailableForProfiles__c))
			{
				continue;
			}

			// if the profile id not in the list of available profiles, remove the field from the list
			if (!currentField.AvailableForProfiles__c.contains(userProfileId))
			{
				fieldSet.remove(currentField);
			}
		}

		fieldList = new List <AdditionalCaseField__c> (fieldSet);
		return fieldList;
	}

	/**
	 * @author dme, ako
	 * @description PARXIMPL-1796 Remove not related to category picklist values
	 */
	public static void removeNotRelatedToCategoryValues(Case newCase, List<AdditionalCaseField__c> aciFields)
	{
		Map<String, Schema.SObjectField> caseFieldMap = Schema.SObjectType.Case.fields.getMap();

		Map<String, List<String>> availableValuesForField = new Map<String, List<String>>();
		for (AdditionalCaseField__c aciField : aciFields)
		{
			String fieldAPIName = aciField.CaseFieldAPIName__c.remove('Case.');
			//isk PARXIMPL-10561 dynamic visibility in a "Master & Servant" ACI Field hierarchy and picklist value dependency
			if (!availableValuesForField.containsKey(fieldAPIName))
			{
				availableValuesForField.put(fieldAPIName, new List<String>());
			}

			if (String.isNotBlank(aciField.CaseFieldValue__c))
			{
				// PARXIMPL-4828 : mtt : Replace Windows new lines to Unix
				String availableValuesStr = aciField.CaseFieldValue__c.replaceAll('\r\n', '\n');
				// PARXIMPL-4747 : ako : there can be extra spaces for each option
				Set<String> availableValues = new Set<String>();
				for (String item: new Set<String>(availableValuesStr.split(ACI_AVAILABLE_VALUE_SEPARATOR)))
				{
					availableValues.add(item.trim());
				}
				availableValuesForField.get(fieldAPIName).addAll(availableValues);
			}
		}

		for (AdditionalCaseField__c aciField : aciFields)
		{
			String fieldAPIName = aciField.CaseFieldAPIName__c.remove('Case.');
			String newValue = '';
			String oldValue = String.valueOf(newCase.get(fieldAPIName));
			if (String.isNotBlank(oldValue))
			{
				List<String> newValues = new List<String>();
				//isk PARXIMPL-12649 picklist values with ';' not visible after saving category
				List<String> oldValues = caseFieldMap.get(fieldAPIName).getDescribe().getType() == DisplayType.MultiPicklist ? oldValue.split(';') : new List<String>{oldValue};
				if (String.isNotBlank(aciField.CaseFieldValue__c))
				{
					for (String oldVal : oldValues)
					{
						if (availableValuesForField.get(aciField.CaseFieldAPIName__c.remove('Case.')).contains(oldVal))
						{
							newValues.add(oldVal);
						}
					}
					newValue = newValues.isEmpty() ? '' : String.join(newValues, Utils.PICKLIST_SEPARATOR);
					newCase.put(fieldAPIName, newValue);
				}
			}
		}
	}

	/**
	*	@author mtt
	*	@description Clears all ACI values from case if they are unrelated with new category
	*	@jira PARXIMPL-3123
	*/
	public static void clearACIvaluesFromUnrelatedCategory(Case newCase, List<AdditionalCaseField__c> aciFields)
	{
		List<AdditionalCaseField__c> oldCategoryFields = [select CaseFieldAPIName__c from AdditionalCaseField__c where AdditionalCaseInformation__r.Category__c = :newCase.Category__c];
	}

	/**
	*	@author ?, ach
	*	@description Removes not for the current profile selected fields from the field list.
	*/
	public static Boolean isFieldFieldValid(AdditionalCaseField__c f, MetadataHelperInterface metadataHelper, Case newCase)
	{
		DisplayType fldType = metadataHelper.getFieldType(f.CaseFieldAPIName__c);

		if (!System.Test.isRunningTest())
		{
			if (fldType == null)
			{
				System.debug('Field ' + f.CaseFieldAPIName__c + ' does not exist on Case');

				//persist error
				try
				{
					ErrorLog__c errorLog = new ErrorLog__c(
						ObjectId__c = newCase.Id,
						User__c = UserInfo.getUserId(),
						ErrorLocation__c = 'Case - Chatter Actions - Additional Information',
						Comment__c = 'Additional Information configuration issue. Field ' + f.CaseFieldAPIName__c + ' does not exist on Case.',
						Status__c = 'New'
					);
					insert errorLog;

				}
				catch (Exception e)
				{
					//Do not handle
				}

				//Skip this field
				return false;
			}
		}

		return true;
	}

	/**
	*	@author ?, ach
	*	@description PARXIMPL-92 Add server side validation for ACIs in FLASH2.
	*	The ACI fields will be selected using the  retrieveAdditionalFields  method from 4.4.1. Here is generic logic which needs to be implemented:
	*	1. Loop through the list of ACI fields from 4.4.1. Validate if  caseToValidate  contains the values for all mandatory ACI fields.
	*	2. If the field value is not present - add validation error to list of errors.
	*/
	public static List<String> validateRequiredFields(Case caseToValidate, Id categoryId, String serviceCountryCode, MetadataHelperInterface metadataHelper)
	{
		List<String> errors = new List<String>();
		List<AdditionalCaseField__c> fields = AdditionalInformationService.retrieveAdditionalFields(serviceCountryCode, categoryId, metadataHelper, caseToValidate);
		Map<String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();
		Schema.SObjectType caseSchema = schemaMap.get('Case');
		Map<String, Schema.SObjectField> fieldMap = caseSchema.getDescribe().fields.getMap();
		//generate fields to validate
		Set<String> fieldsToValidate = new Set<String>();
		Set<String> allApiFields = new Set<String>();
		for (AdditionalCaseField__c additionalField : fields)
		{
			allApiFields.add(additionalField.CaseFieldAPIName__c.contains('.') ? additionalField.CaseFieldAPIName__c.replaceAll('^.*\\.', '') : additionalField.CaseFieldAPIName__c);
		}

		Case caseToUse = caseToValidate;
		if (caseToValidate != null && String.isNotEmpty(caseToValidate.Id) && fields.size() > 0)
		{
			String additionalFieldsToSelect = String.escapeSingleQuotes(String.join(new List<String>(allApiFields), ','));
			Id newCaseId = caseToValidate.Id;
			List<SObject> cases = Database.query('SELECT Id, Category__r.Name, Contact.Email, Contact.MobilePhone, Category__c, ProductId, Product.MerchandiseSubGroupLookup__c, Product.MerchandiseGroupLookup__c, ' +
					'CriticismFlag__c, CriticalFlag__c, ' + additionalFieldsToSelect + ' FROM Case WHERE Id = :newCaseId');
			if (cases.size() == 1)
			{
				caseToUse = (Case)cases[0];
			}
		}
		//remove duplicates: we can have different ACI fields for different products
		fields = removeDuplicates(caseToUse, fields);

		for (AdditionalCaseField__c additionalField : fields)
		{
			//dch: PARXIMPL-3114: check if this field may be skipped
			if (additionalField.Mandatory__c == true && !additionalField.CC_UnknownValueAllowed__c)
			{
				String caseFieldAPI;
				caseFieldAPI = additionalField.CaseFieldAPIName__c.contains('.') ? additionalField.CaseFieldAPIName__c.replaceAll('^.*\\.', '') : additionalField.CaseFieldAPIName__c;
				fieldsToValidate.add(caseFieldAPI);
			}
		}
		for (String caseFieldAPI : fieldsToValidate)
		{
			Boolean isValid = false;
			try
			{
				Object theValue = caseToValidate.get(caseFieldAPI);
				//dme: PARXIMPL-815
				// 1. {Case.Field__c = null} - on upsert we will set it to null, so we keep the existing value.
				// 2. {Case.Field__c is not defined on case at all} => we need to check the DB - caseToUse
				if (theValue == null && !FieldUtils.hasSObjectField(caseFieldAPI, caseToValidate))
				{
					theValue = caseToUse.get(caseFieldAPI);
				}

				if (theValue != null)
				{
					//validate String
					String theStringValue = String.valueOf(theValue);
					if (String.isNotBlank(theStringValue))
					{
						isValid = true;
					}
				}
			} catch(Exception e)
			{
				System.debug('###:' + e.getMessage());
			}
			if (!isValid)
			{
				Schema.SObjectField sobjectField = fieldMap.get(caseFieldAPI);
				String param = '';
				if (sobjectField != null)
				{
					param = sobjectField.getDescribe().getLabel();
				}
				errors.add(String.format(Label.RequiredFieldErrorMessage, new List<String>{param}));
			}
		}
		return errors;
	}

	public static List<AdditionalCaseField__c> removeDuplicates(Case currentCase, List<AdditionalCaseField__c> additionalCaseFields)
	{
		List<AdditionalCaseField__c> result = new List<AdditionalCaseField__c>();
		Map<String, AcceptableAdditionalField> fieldsMap = new Map<String, AcceptableAdditionalField>();
		for (AdditionalCaseField__c a : additionalCaseFields)
		{
			//isk PARXIMPL-10561/PARXIMPL-11916 check uniqueness by key instead of CaseFieldName
			// npo PARXIMPL-15761: check uniqueness also by Purchase Channel
			String fieldUniqueKey = a.CaseFieldAPIName__c + (a.CC_ControllingParent__c != null ? String.valueOf(a.CC_ControllingParent__c) : '') + (String.isNotBlank(a.CC_ControllingParentValue__c) ? a.CC_ControllingParentValue__c : '') + (String.isNotBlank(a.CC_ControllingPurchaseChannel__c) ? a.CC_ControllingPurchaseChannel__c : '');
			if (!fieldsMap.containsKey(fieldUniqueKey))
			{
				//US53, SCSI-1046. Only one field with the same API should be used, therefore the next priority rule is used: field with ProductSubGroup; with MerchandiseGroup; lookups are empty.
				fieldsMap.put(fieldUniqueKey, new AcceptableAdditionalField(currentCase));
			}
			fieldsMap.get(fieldUniqueKey).putCandidate(a);
		}

		System.debug('!!!!!fieldsMap: ' + fieldsMap);

		//additionalCaseFields.clear();
		for (String fieldKey : fieldsMap.keySet())
		{
			if (fieldsMap.get(fieldKey).getAccepted() != null)
			{
				result.add(fieldsMap.get(fieldKey).getAccepted());
			}
		}
		return result;
	}

	public static Case setCriticalFlag(Case caseRecord, String casefieldName, String fieldApiName, String fieldApiValue, Map<String, String> result, Boolean toUpdate)
	{
		Boolean isCriticalOrCritism = false;

		// collect all picklists values which have critical values configured.
		Set<String> picklistsApiNames = getCriticalPicklistNames(fieldApiName, result);

		System.debug('*** fieldApiValue ' + fieldApiValue);
		System.debug('*** fieldApiName ' + fieldApiName);
		System.debug('*** result ' + result);
		System.debug('*** picklistsApiNames ' + picklistsApiNames);
		// loop through current field and set flag to know that this value is critical or critisim e.g. CriticalFlag__c-Status:Categorized=Categorized, fieldApiValue is current value of the UI
		// in case of multiple values split it.
		if (String.isNotBlank(fieldApiValue))
		{
			for (String s : fieldApiValue.split(';'))
			{
				// loop through result and check whether a value exist
				for (String keyValue : result.keySet())
				{
					String names = keyValue.split(':').get(0);
					if (result.get(keyValue) != null && result.get(keyValue) == s && names.split('-').get(1) == fieldApiName)
					{
						isCriticalOrCritism = true;
						break;
					}
				}
			}
		}

		System.debug('*** isCriticalOrCritism ' + isCriticalOrCritism);

		if (!picklistsApiNames.isEmpty())
		{
			// dvo : PARXIMPL-4191 : reducing DML statements : as we always have context case (on CaseNew and on the sidebar) to work with
			// we don't need to query it, so DE443 are removed as not relevant

			// loop through other case fields and set flag to know that this value is critical or critisim
			// in case of other picklist were previously set as critical they have to be looped again otherwise it will be set as false.
			for (String s : picklistsApiNames)
			{
				if (isCriticalOrCritism)
				{
					break;
				}
				for (String keyValue : result.keySet())
				{
					String currentFieldValue = s.contains('.') ? Utility.getLookupFieldValue(caseRecord, s) : String.valueOf(caseRecord.get(s));
					//dme : PARXIMPL-2029 : Convert picklist value String to Set
					Set<String> currentFieldValues = String.isNotBlank(currentFieldValue) ? new Set<String>(currentFieldValue.split(';')) : new Set<String>();
					if (result.get(keyValue) != null && currentFieldValues.contains(result.get(keyValue)))
					{
						isCriticalOrCritism = true;
						break;
					}
				}
			}
		}
		System.debug('*** isCriticalOrCritism2 ' + isCriticalOrCritism);
		// PARXIMPL-1884 npo: Case isn't marked as critical if "Did Illness / Injury Occur?" value is "Yes"
		if (caseRecord.get(casefieldName) != isCriticalOrCritism)
		{
			FieldUtils.setFieldValue(caseRecord, casefieldName, isCriticalOrCritism, toUpdate);
		}

		return caseRecord;
	}

	// collect all picklist api names which have critical values configured.
	public static Set<String> getCriticalPicklistNames(String currentFieldApiName, Map<String, String> criticalMap)
	{
		Set<String> picklistsApiNames = new Set<String>();
		for (String s : criticalMap.keySet())
		{
			String names = s.split(':').get(0);
			if (currentFieldApiName != names.split('-').get(1))
			{
				// Remove ACI field prefix if present
				String picklistApiName = names.split('-').get(1);
				if (picklistApiName.contains('Case.'))
				{
					picklistApiName = picklistApiName.remove('Case.');
				}
				picklistsApiNames.add(picklistApiName);
			}
		}
		return picklistsApiNames;
	}

	/**
	*	@description: US53, SCSI-1046. Wraps the 'Additional Case Field' filter logic.
	*/
	public class AcceptableAdditionalField
	{
		private Case contextCase;

		private AdditionalCaseField__c potentiallyAcceptableItem;

		public AcceptableAdditionalField(Case contextCase)
		{
			this.contextCase = contextCase;
		}

		/**
		*	@description: US53, SCSI-1046. Only one field with the same API should be used, therefore the next priority rule is used: field with ProductSubGroup; with MerchandiseGroup; lookups are empty.
		*/
		public void putCandidate(AdditionalCaseField__c candidate)
		{
			if (!this.isSubGroupConfigured(this.potentiallyAcceptableItem) && this.isSubGroupConfigured(candidate) ||
					!this.isSubGroupConfigured(this.potentiallyAcceptableItem) && !this.isGroupConfigured(this.potentiallyAcceptableItem) && this.isGroupConfigured(candidate) ||
					!this.isSubGroupConfigured(this.potentiallyAcceptableItem) && !this.isGroupConfigured(this.potentiallyAcceptableItem) && !this.isNotConfigured(this.potentiallyAcceptableItem) && this.isNotConfigured(candidate))
			{
				this.potentiallyAcceptableItem = candidate;
			}
		}

		private Boolean isSubGroupConfigured(AdditionalCaseField__c additionalCaseField)
		{
			return additionalCaseField != null && String.isNotBlank(this.contextCase.ProductId) &&
					String.isNotBlank(this.contextCase.Product.MerchandiseSubGroupLookup__c) &&
					additionalCaseField.MerchandiseSubGroup__c == this.contextCase.Product.MerchandiseSubGroupLookup__c;
		}

		private Boolean isGroupConfigured(AdditionalCaseField__c additionalCaseField)
		{
			return additionalCaseField != null && String.isNotBlank(this.contextCase.ProductId) &&
				String.isNotBlank(this.contextCase.Product.MerchandiseGroupLookup__c) &&
					additionalCaseField.MerchandiseGroup__c == this.contextCase.Product.MerchandiseGroupLookup__c;
		}

		private Boolean isNotConfigured(AdditionalCaseField__c additionalCaseField)
		{
			return additionalCaseField != null && String.isBlank(additionalCaseField.MerchandiseGroup__c) &&
					String.isBlank(additionalCaseField.MerchandiseSubGroup__c);
		}

		public AdditionalCaseField__c getAccepted()
		{
			return this.potentiallyAcceptableItem;
		}
	}
}