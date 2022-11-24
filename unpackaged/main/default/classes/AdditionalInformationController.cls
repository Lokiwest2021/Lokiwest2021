/**
*   Controller Class for the Additional Information page.
*
*   @author mto, yle, ypa, dvo, ach, dme, npo, rby
*   @copyright PARX
*/
global with sharing class AdditionalInformationController
{
	// ### HOTFIX ###
	// Trying to deploy this class without those properties caused an error on deployment.
	// The property <TYPE> <PROPERTYNAME> is referenced by Visualforce Page in salesforce.com. Remove the usage and try again.
	// See https://success.salesforce.com/issues_view?id=a1p300000008YkUAAU
	// TODO: delete this hotfix properties once deployed to production
	public String selectedDepartment {get; set;}
	public List<SelectOption> departments {get; set;}
	// ### HOTFIX END ###

	public String aciCategoryId { get; set; }
	/**
	 * Used to pass category Id in Action Page
	 */
	public String aciCategoryActionId { get; set; }
	private Boolean initialized = false;
	public String errorMessage { get; set; }
	public String dummy { get; set; }
	public Case newCase { get; set; }
	public AdditionalCaseField__c[] fields { get; set; }
	public String serviceCountryCode { get; set; }
	public String language { get; set; }
	public String[] multi = new String[]
	{
	};
	//dme : PARXIMPL-6036 : Added transient keyword to reduce view state
	public transient String dynamicFormHtml { get; set; }
	public Boolean hasMandatory { get; set; }
	public MetadataHelperInterface metadataHelper = new MetadataHelper();

	public Map<String, String> defaultStringValueByDisplayType { get; set; }

	//private Map<String, String> isCritismMap;
	private Map<String, String> isCriticalMap;

	@TestVisible
	private AdditionalInformationService additionalInformationServiceImpl = new AdditionalInformationService();

	//US210. To execute logic only within the flash interface.
	public Boolean isNotCaseNewInterface
	{
		get
		{
			if (this.isNotCaseNewInterface == null)
			{
				return false;
			}
			return this.isNotCaseNewInterface;
		}
		set;
	}

	//US275. Determines current state of the secondary section: shown or hidden.
	public Boolean isSecondarySectionShown {get; set;}

	/*private Boolean isAura = false;*/
	/*
    *   @description Page Controller instance.
    */
	public CaseNewController pageContr {get;set;}

	// PARXIMPL-844 npo: Determines if ACI fields should be updated immediately when changed
	public Boolean immediateUpdateValue { get; set; }

	/**
	 * Constructor called from the new case wizard
	 */
	public AdditionalInformationController()
	{
		hasMandatory = false;
		//isCritismMap = new Map<String, String>();
		isCriticalMap = new Map<String, String>();
		initCountry();
		defaultStringValueByDisplayType = FieldUtils.getDefaultStringValueByDisplayType();
	}

	/**
	 * Constructor called from the new case wizard
	 */
	public AdditionalInformationController(Case cs)
	{
		/*this.isAura = true;*/
		this.newCase = cs;
		this.aciCategoryId = cs.Category__c;
		hasMandatory = false;
		isCriticalMap = new Map<String, String>();
		defaultStringValueByDisplayType = FieldUtils.getDefaultStringValueByDisplayType();
	}

	public void reloadFields()
	{
		// PARXIMPL-7044 npo
		if (String.isEmpty(serviceCountryCode))
		{
			initCountry();
		}
		System.debug('in reloadFields ' + this.newCase);
		try
		{
			//US275. Resetes the visibility of the secondary section.
			if (this.fields == null || this.fields.isEmpty() || this.fields.get(0).AdditionalCaseInformation__r.Category__c != this.aciCategoryId)
			{
				this.isSecondarySectionShown = false;
			}

			System.debug('reloadFields ');
			this.errorMessage = null;
			//PARXIMPL-92 Add server side validation for ACIs in FLASH2
			this.fields = AdditionalInformationService.loadCaseFields(serviceCountryCode, this.aciCategoryId, this.newCase);

			//Called only in CaseNew
			//select all necessary fields from Case

			//DE985. In case if the case has been already persisted, but without selected contact - we should preserve it to be able to fetch it additionally below.
			Id contactId = this.newCase.ContactId;

			if (this.newCase != null && String.isNotEmpty(this.newCase.Id) && fields.size() > 0)
			{

				if (!Test.isRunningTest())
				{
					loadCaseWithACIFields();
				}
			}

			//DE781, DE985. For the reservation related fields population(US210) we always have to obtain the related contact fields.
			if (this.newCase.getPopulatedFieldsAsMap().get('Contact') == null && String.isNotBlank(contactId))
			{
				List<Contact> relatedContacts = DatabaseUtils.getRelatedSobjects(
					'Contact',
					new List<String>{'Id', 'Email', 'MobilePhone'},
					new Set<Id>{contactId}
				);
				if (!relatedContacts.isEmpty())
				{
					this.newCase.Contact = relatedContacts.get(0);
				}
			}

			//To execute logic only within the flash interface.
			if (!this.isNotCaseNewInterface)
			{
				//US210. If email AND OR mobile phone are already defined at Contact Data the informations have to be pre-filled at the email and phone fields automatically.
				//Otherwise the fields are reseted.
				this.additionalInformationServiceImpl.prefillPreferredCommunicationChannel(this.newCase, this.aciCategoryId);
			}

			// remove duplicates fields
			this.fields = AdditionalInformationService.removeDuplicates(this.newCase, this.fields);

			//npo PARXIMPL-2829: ACI Field Values are transferred to a new category by CAT Chatter Action although the value does not exist in the target category
			AdditionalInformationService.removeNotRelatedToCategoryValues(this.newCase, this.fields);
			setFormHtml();

		}
		catch (DMLException e)
		{
			this.errorMessage = ErrorMessageUtil.getUserFriendlyMessageDml(e);
			System.debug('errorMessage ' + e);
		}
		catch (Exception e)
		{
			this.errorMessage = ErrorMessageUtil.getUserFriendlyMessage(e);
			System.debug('errorMessage ' + e + ' : ' + e.getStackTraceString());
		}
	}

	private void setFormHtml()
	{
		System.debug(loggingLevel.WARN, '....setFormHtml ');
		try
		{

			this.dynamicFormHtml = '';
			for (AdditionalCaseField__c field : this.fields)
			{

				System.debug('ACI field ' + field);
				this.hasMandatory = this.hasMandatory == false ? field.Mandatory__c : true;

				DisplayType fldType = metadataHelper.getFieldType(field.CaseFieldAPIName__c);
				System.debug('ACI field type' + fldType);
				String jsChangeEvent = ' onblur="saveFieldJs($(this).attr(\'id\'), $(this).val(), \'' + fldType + '\')"';

				//Mandatory fields
				String required = field.Mandatory__c == true ? ' required ' : '';

				Boolean enabled;

				//DE98. A community user shouldn't see additional fields on read-only record.
				if (Network.getNetworkId() != null)
				{
					enabled = false;
				}
				else
				{
					enabled = FieldUtils.hasValue(this.newCase, field.CaseFieldAPIName__c);
				}
				// yle : assign crical, critism mapping
				isCriticalMap = metadataHelper.getMappingForCriticalCritism(field, true, true, isCriticalMap);
				System.debug('isCriticalMap *** ' + isCriticalMap);

				if (AdditionalInformationForm.TEMPLATE_MAP.keySet().contains(fldType))
				{
					Object savedValue;
					if (DisplayType.DATE == fldType)
					{
						savedValue = FieldUtils.getFieldValueDate(this.newCase, field.CaseFieldAPIName__c);
					}
					else if (DisplayType.DATETIME == fldType)
					{
						savedValue = FieldUtils.getFieldValueDateTime(this.newCase, field.CaseFieldAPIName__c);
					}
					else if (DisplayType.DOUBLE == fldType)
					{
						// dvo : PARXIMPL-3858 : Display double values according to the current user locale
						savedValue = Decimal.valueOf(FieldUtils.getFieldValueDouble(this.newCase, field.CaseFieldAPIName__c)).format();
					}
					else
					{
						savedValue = FieldUtils.getFieldValueString(this.newCase, field.CaseFieldAPIName__c);
					}
					System.debug(loggingLevel.WARN, '....savedValue: ' + savedValue);

					List<ACIOption> options = additionalInformationServiceImpl.getOptionsForField(field, String.valueOf(savedValue));
					System.debug(loggingLevel.WARN, '....options: ' + options);
					prefillPicklistWithSingleItem(options);
					AdditionalInformationForm form = new AdditionalInformationForm();
					form.addElement(fldType, field.CaseFieldAPIName__c, savedValue,
						FieldUtils.getFieldLabel('Case', field.CaseFieldAPIName__c),
						field.Mandatory__c, enabled, FieldUtils.getMaxLength(field.CaseFieldAPIName__c),
						options, field.IsHidden__c, field.Id, field.CC_UnknownValueAllowed__c);
					this.dynamicFormHtml += form.html;

					//isk: PARXIMPL-6761: checkbox (NOT ACI field) that define if the ACI "Best before date" mean as a full date or only as month and year
					if (field.CaseFieldAPIName__c.contains('ACI_BestBeforeDate__c'))
					{
						AdditionalInformationForm form1 = new AdditionalInformationForm();
						savedValue = FieldUtils.getFieldValueString(this.newCase, 'Case.CC_BestBeforeDateIsMonthly__c');
						form1.addElement(DisplayType.BOOLEAN, 'CC_BestBeforeDateIsMonthly__c', savedValue,
								'Best Before Date is Monthly', false, true, 1, null, false, 'fakeId', false);
						this.dynamicFormHtml += form1.html;
					}

				}
			}
		}
		catch (DMLException e)
		{
			System.debug('...DMLException:' + e);
			this.errorMessage = ErrorMessageUtil.getUserFriendlyMessageDml(e);
		}
		catch (Exception e)
		{
			System.debug('...Exception:' + e);
			this.errorMessage = ErrorMessageUtil.getUserFriendlyMessage(e);
		}
	}

	/*
	 *	@author dvo
	 *	@description Method prefills the value of the picklist on the form if the picklist contains only one item
	 */
	private void prefillPicklistWithSingleItem(List<ACIOption> options)
	{
		if ( options.size() == 1 )
		{
			options[0].selected = true;
		}
	}

	public PageReference saveField()
	{
		this.errorMessage = null;
		try
		{
			String fieldApiName = (String) System.currentPageReference().getParameters().get('fieldApiName');
			String fieldApiValue = (String) System.currentPageReference().getParameters().get('fieldApiValue');
			String fieldApiType = (String) System.currentPageReference().getParameters().get('fieldApiType');

			System.debug('fieldApiName: ' + fieldApiName + 'fieldApiValue: ' + fieldApiValue + ' / fieldApiType: ' + fieldApiType);

			if (String.isEmpty(fieldApiName) || String.isEmpty(fieldApiType))
			{
				return null;
			}

			//refresh field in Case object
			if (!Test.isRunningTest())
			{
				// add load fields
				loadCaseWithACIFields();
			}

			Boolean toUpdate = String.isNotEmpty(this.newCase.Id) && immediateUpdateValue;

			//TODO: make investigation with following refactoring if needed
			if (this.newCase != null)
			{
				if ('DOUBLE'.equals(fieldApiType))
				{
					//DE908, DE931, DE932
					if (String.isNotEmpty(fieldApiValue))
					{
						try
						{
							validateAndSetACIDoubleValue(fieldApiName, fieldApiValue, false);
						}
						catch (TypeException typeException)
						{
							// try to swap dots and commas delimiters and save again for different locale type
							String stringValueWithChangedDelimiters = String.valueOf(fieldApiValue).replaceAll(',', 'c').replaceAll('\\.', 'p').replaceAll('c', '.').replaceAll('p', ',');
							try
							{
								validateAndSetACIDoubleValue(fieldApiName, stringValueWithChangedDelimiters, false);
							}
							catch (TypeException theTypeEx)
							{
								// if changing of the delimiters didn't help - throw initial error to display on ui
								throw typeException;
							}
						}
					}
					else
					{
						// rby : PARXIMPL-4191 : store changes in context Case without performing DML
						this.newCase = (Case)FieldUtils.setFieldValue(this.newCase, fieldApiName, null, false);
					}
				}
				else if ('BOOLEAN'.equals(fieldApiType))
				{
					//DE908, DE931, DE932
					if (String.isNotEmpty(fieldApiValue))
					{
						// rby : PARXIMPL-4191 : store changes in context Case without performing DML
						this.newCase = (Case)FieldUtils.setFieldValue(this.newCase, fieldApiName, Boolean.valueOf(fieldApiValue), false);
					}
				}
				else if ('DATE'.equals(fieldApiType))
				{
					//DE908, DE931, DE932
					if (String.isNotEmpty(fieldApiValue))
					{
						Date dateParsed = DateUtil.parseStringToDate(fieldApiValue);
						System.debug(loggingLevel.WARN, '....fieldApiValue: ' + fieldApiValue);
						System.debug(loggingLevel.WARN, '....dateParsed: ' + dateParsed);
						if (dateParsed != null)
						{
							// dvo : PARXIMPL-4191 : store changes in context Case without performing DML
							this.newCase = (Case)FieldUtils.setFieldValue(this.newCase, fieldApiName, DateUtil.parseStringToDate(fieldApiValue), false);
						}
						else
						{
							System.debug('Wrong date format');
						}
					} else
					{
						// rby : PARXIMPL-4191 : store changes in context Case without performing DML
						this.newCase = (Case)FieldUtils.setFieldValue(this.newCase, fieldApiName, null, false);
					}
				}
				else if ('DATETIME'.equals(fieldApiType))
				{
					//DE908, DE931, DE932
					if (String.isNotEmpty(fieldApiValue))
					{
						DateTime dateParsed = DateUtil.parseStringToDate(fieldApiValue);
						System.debug('dateParsed: ' + dateParsed + ' this.newCase: ' + this.newCase);
						if (dateParsed != null)
						{
							// rby : PARXIMPL-4191 : store changes in context Case without performing DML
							this.newCase = (Case)FieldUtils.setFieldValue(this.newCase, fieldApiName, DateUtil.parseStringToDateTime(fieldApiValue), false);
						}
						else
						{
							System.debug('Wrong date format');
						}
					}
					else
					{
						// rby : PARXIMPL-4191 : store changes in context Case without performing DML
						this.newCase = (Case)FieldUtils.setFieldValue(this.newCase, fieldApiName, null, false);
					}
				}
				else
				{
					System.debug('default save name ' + fieldApiName + ' value:' + fieldApiValue + ' toUpdate:' + toUpdate);

					// rby : PARXIMPL-4191 : store changes in context Case without performing DML
					this.newCase = (Case)FieldUtils.setFieldValue(this.newCase, fieldApiName, fieldApiValue, false);
				}

				// yle: if field type is picklist apply critical or critisim logic
				if ('MULTIPICKLIST'.equals(fieldApiType) || 'PICKLIST'.equals(fieldApiType))
				{
					// PARXIMPL-8408 npo
					recalculateCriticalFlag();
					System.debug('...recalculateCriticalFlag ' + newCase.CriticalFlag__c);
				}

				//if this case is already saved then do an update
				// dvo : PARXIMPL-4191 : removed Test.isRunningTest() as without this tests will fail as at the moment they are relate to the database
				if (String.isNotEmpty(this.newCase.Id) && immediateUpdateValue)
				{
					update this.newCase;

					//dme PARXIMPL-644 Set errorMessage based on CaseSyncService.failedDMLs
					if (String.isNotBlank(CaseSyncService.failedDMLs))
					{
						this.errorMessage = String.format(Label.CaseSyncError, new List<String> {this.newCase.CaseNumber, CaseSyncService.failedDMLs});
					}
				}
			}

			//if saving from CaseNew screen
			if (this.newCase.ContactId != null && (fieldApiName.startsWith('Contact.') || fieldApiName.startsWith('Case.Contact.')))
			{
				if (fieldApiName.startsWith('Case.Contact.'))
				{
					fieldApiName = fieldApiName.remove('Case.');
				}

				String column = String.escapeSingleQuotes(fieldApiName.substringAfter('.'));
				String contactId = this.newCase.ContactId;
				List<Contact> contacts = Database.query('select ' + column + ' from Contact where Id = :contactId');
				if (contacts != null && contacts.size() == 1)
				{
					SObjectType objToken = Schema.getGlobalDescribe().get('Contact');
					DescribeSObjectResult objDef = objToken.getDescribe();
					Map<String, SObjectField> fields = objDef.fields.getMap();
					SObjectField f = fields.get(fieldApiName.substringAfter('.'));

					if ('DOUBLE'.equals(fieldApiType))
					{
						contacts[0].put(f, Double.valueOf(fieldApiValue));
					}
					else
					{
						contacts[0].put(f, fieldApiValue);
					}

					update contacts[0];
				}
			}

			// dvo: clean parent messages on update ACI field
			cleanFormMessages();
		}
		catch (DMLException e)
		{
			System.debug('....DMLException: ' + e);
			this.errorMessage = ErrorMessageUtil.getUserFriendlyMessageDml(e);
			if (this.errorMessage.indexOf('insufficient access rights on object id') > -1)
			{
				this.errorMessage = Label.CaseReadPermissionError;
			}
		}
		catch (Exception e)
		{
			System.debug('....Exception: ' + e + ', ' + e.getStackTraceString());
			this.errorMessage = ErrorMessageUtil.getUserFriendlyMessage(e);
		}

		return null;
	}

	/*
	 *	@author npo
	 *	@jira PARXIMPL-8408
	 *	@description Method that recalculates CriticalFlag__c
	 */
	public void recalculateCriticalFlag()
	{
		Map<String, AdditionalCaseField__c> aciMap = new Map<String, AdditionalCaseField__c>();
		for (AdditionalCaseField__c aciField : fields)
		{
			aciMap.put(aciField.CaseFieldAPIName__c, aciField);
		}

		Map<String, SObjectField> caseFields = Case.getSObjectType().getDescribe().fields.getMap();

		Boolean isCritical = false;
		for (String field : aciMap.keySet())
		{
			if (isCritical)
			{
				break;
			}

			DescribeFieldResult currentField = caseFields.get(field.replace('Case.', '')).getDescribe();
			String type = String.valueOf(currentField.getType());
			if (aciMap.get(field) != null && ('MULTIPICKLIST'.equalsIgnoreCase(type) || 'PICKLIST'.equalsIgnoreCase(type)))
			{
				AdditionalInformationService.setCriticalFlag(this.newCase, 'CriticalFlag__c', field , String.valueOf(newCase.get(field.replace('Case.', ''))), isCriticalMap, false);
				isCritical = this.newCase.CriticalFlag__c;
			}
		}
	}

	/*
	 *	@author dvo
	 *	@description method validate the number of digits after delimiter and tries to save double value. If validation fails System.SObjectException is thrown
	 */
	private void validateAndSetACIDoubleValue(String fieldApiName, String fieldApiValue, Boolean toUpdate)
	{
		// validate the number of digits after delimiter
		if ( !FieldUtils.validateFieldValueScale('Case', fieldApiName, fieldApiValue, '.') )
		{
			throw new System.SObjectException(Label.ACIDecimalFractioanlPartTooLong + ' ' + FieldUtils.getDecimaFieldlScale('Case', fieldApiName));
		}
		else
		{
			// try to save
			this.newCase = (Case)FieldUtils.setFieldValue(this.newCase, fieldApiName, Double.valueOf(fieldApiValue), toUpdate);
		}
	}

	private void initCountry()
	{
		serviceCountryCode = UserService.getCountryCode();
		// PARXIMPL-7044 npo
		if (String.isEmpty(serviceCountryCode) && this.newCase != null)
		{
			serviceCountryCode = this.newCase.ServiceCountryCode__c;
		}
		System.debug('serviceCountryCode === ' + serviceCountryCode);
	}

	public PageReference dummy()
	{
		return null;
	}

	class ACIException extends Exception
	{
	}

	/*
	* DE698: Mark form valid
	 */
	public void formIsValid()
	{
		if(pageContr != null)
		{
			this.pageContr.isACIFormValid = true;
		}
	}

	/*
	* DE698: Mark form invalid
	 */
	public void formIsInvalid()
	{
		if(pageContr != null)
		{
			this.pageContr.isACIFormValid = false;
		}
	}

	public void cleanFormMessages()
	{
		if(pageContr != null)
		{
			this.pageContr.errorMessage = null;
			this.pageContr.infoMessage = null;
		}
	}

	/*
	 *	@author ?
	 *	@refactored by npo in scope of PARXIMPL-8408
	 *	@description Method loads Case with proper ACI values
	 */
	private void loadCaseWithACIFields()
	{
		String additionalFields = '';
		Set<String> fieldSets = new Set<String>();
		for (AdditionalCaseField__c f : fields)
		{
			//DE698: Retain if mandatory fields exist in apex so we can disable the save buttons in FLaSH
			if(this.pageContr != null)
			{
				this.pageContr.isACIFormValid = f.Mandatory__c ? false : this.pageContr.isACIFormValid;
			}

			String caseFieldAPI = f.CaseFieldAPIName__c.contains('.') ? f.CaseFieldAPIName__c.replaceAll('^.*\\.', '') : f.CaseFieldAPIName__c;

			// avoide duplicate field selections
			if (!fieldSets.contains(caseFieldAPI))
			{
				additionalFields += caseFieldAPI + ',';// (cnt == fields.size() ? '' : ',');
				fieldSets.add(caseFieldAPI);
			}
		}

		String caseId = this.newCase.Id;

		additionalFields = String.escapeSingleQuotes(additionalFields);
		List<sObject> cases = Database.query('SELECT Id, Category__r.Name, Contact.Email, Contact.MobilePhone, ' +
				'Category__c, ProductId, Product.MerchandiseSubGroupLookup__c, CC_BestBeforeDateIsMonthly__c, ' +
				'Product.MerchandiseGroupLookup__c, CriticismFlag__c, CriticalFlag__c, ServiceCountryCode__c, ' +
				additionalFields.substring(0, additionalFields.length() - 1) +
				' FROM Case WHERE Id = :caseId');

		if (cases != null && cases.size() == 1)
		{
			this.newCase = (Case)cases[0];
		}
	}
}