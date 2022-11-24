/**
 * @author dme
 * @copyright PARX
 */
public with sharing class AgentWorkService
{
	//dme : PARXIMPL-10837 : We need to skip AgentWork creation in some cases; e.g. after Merge to Higher level
	public static Boolean skipAgentWorkCreation = false;

	/**
	 * @author dme
	 * @description PARXIMPL-1761
	 */
	public static List<AgentWork> getActiveAgentWorks(Set<Id> caseIds)
	{
		List<AgentWork> result = new List<AgentWork>();
		if (caseIds != null && !caseIds.isEmpty())
		{
			result = [SELECT Id, WorkItemId FROM AgentWork WHERE WorkItemId IN :caseIds AND Status IN :CC_Constants.AGENTWORK_ACTIVE_STATUSES];
		}

		return result;
	}

	/**
	 * @author dme
	 * @description Returns active agent works for context User
	 * @jira PARXIMPL-3837
	 */
	public static List<AgentWork> getActiveAgentWorksForCurrentUser()
	{
		List<AgentWork> agentWorks = [SELECT Id, WorkItemId, CapacityWeight FROM AgentWork WHERE UserId = :UserInfo.getUserId() AND Status IN :CC_Constants.AGENTWORK_ACTIVE_STATUSES];

		Map<Id, AgentWork> agentWorkByMessagingSession = new Map<Id, AgentWork>();
		for (AgentWork aw: agentWorks)
		{
			if (aw.WorkItemId != null && aw.getSobjectType() == Schema.MessagingSession.SObjectType)
			{
				agentWorkByMessagingSession.put(aw.WorkItemId, aw);
			}
		}

		// ako : PARXIMPL-9723 : replacemnt is add to avoid AgentWork duplicate creation
		for (MessagingSession ms: [SELECT Id, CaseId FROM MessagingSession WHERE Id IN :agentWorkByMessagingSession.keySet()])
		{
			agentWorkByMessagingSession.get(ms.Id).WorkItemId = ms.CaseId;
		}

		return agentWorks;
	}

	/**
	 * @author dme
	 * @description PARXIMPL-1761 Get "in progress" case Ids
	 */
	public static Set<Id> getCaseIdsWithActiveAgentWorks(Set<Id> caseIds)
	{
		Set<Id> result = new Set<Id>();
		List<AgentWork> agentWorks = getActiveAgentWorks(caseIds);
		for (AgentWork agentWorkRecord : agentWorks)
		{
			result.add(agentWorkRecord.WorkItemId);
		}

		return result;
	}

	/**
	 * @author dme
	 * @description Convert standard object to it custom copy
	 * @jira PARXIMPL-8627
	 */
	public static List<CC_AgentWorkCloned__c> copyAgentWorks(List<AgentWork> agentWorks)
	{
		List<CC_AgentWorkCloned__c> result = new List<CC_AgentWorkCloned__c>();
		for (AgentWork record : agentWorks)
		{
			result.add(copyAgentWork(record));
		}

		return result;
	}

	/**
	 * @author dme
	 * @description Convert standard object to it custom copy
	 * @jira PARXIMPL-8627
	 */
	public static CC_AgentWorkCloned__c copyAgentWork(AgentWork record)
	{
		CC_AgentWorkCloned__c result = new CC_AgentWorkCloned__c();
		if (record != null)
		{
			//dme : PARXIMPL-9574 : There are no Owner.Name value in triggers
			String ownerName = record.Owner.Name;
			// ako : PARXIMPL-15312 : Improve UserService allUsers Query
			User contexUser = UserService.getUserFromCache(record.OwnerId);
			if (String.isBlank(ownerName) && contexUser != null)
			{
				ownerName = contexUser.Name;
			}

			result.CC_AcceptDateTime__c = record.AcceptDateTime;
			//dme : PARXIMPL-12278 : Updated to custom formula field
			result.CC_ActiveTime__c = record.CC_ActiveTime__c;
			result.CC_AgentCapacityWhenDeclined__c = record.AgentCapacityWhenDeclined;
			result.CC_CancelDateTime__c = record.CancelDateTime;
			result.CC_CloseDateTime__c = record.CloseDateTime;
			result.CC_CreatedById__c = record.CreatedById;
			result.CC_CreatedDate__c = record.CreatedDate;
			result.CC_CurrencyIsoCode__c = record.CurrencyIsoCode;
			result.CC_DeclineDateTime__c = record.DeclineDateTime;
			result.CC_DeclineReason__c = record.DeclineReason;
			result.CC_OriginalGroupId__c = record.OriginalGroupId;
			result.CC_OriginalGroupName__c = record.OriginalGroup.Name;
			result.CC_PreferredUserId__c = record.PreferredUserId;
			result.CC_HandleTime__c = record.HandleTime;
			result.CC_LastModifiedById__c = record.LastModifiedById;
			result.CC_LastModifiedDate__c = record.LastModifiedDate;
			result.CC_OwnerId__c = record.OwnerId;
			result.CC_OwnerName__c = ownerName;
			result.CC_PendingServiceRoutingId__c = record.PendingServiceRoutingId;
			result.CC_PercentageOfCapacity__c = record.CapacityPercentage;
			result.CC_PushTimeout__c = record.PushTimeout;
			result.CC_PushTimeoutDateTime__c = record.PushTimeoutDateTime;
			result.CC_OriginalQueueId__c = record.OriginalQueueId;
			result.CC_OriginalQueueName__c = record.OriginalQueue.Name;
			result.CC_RequestDateTime__c = record.RequestDateTime;
			result.CC_RoutingModel__c = record.RoutingModel;
			result.CC_RoutingPriority__c = record.RoutingPriority;
			result.CC_RoutingType__c = record.RoutingType;
			result.CC_ServiceChannelId__c = record.ServiceChannelId;
			result.CC_ServiceChannelName__c = record.ServiceChannel.MasterLabel;
			result.CC_ShouldSkipCapacityCheck__c = record.ShouldSkipCapacityCheck;
			result.CC_SpeedToAnswer__c = record.SpeedToAnswer;
			result.CC_Status__c = record.Status;
			result.CC_UnitsOfCapacity__c = record.CapacityWeight;
			result.CC_UserId__c = record.UserId;
			result.CC_WorkItemId__c = record.WorkItemId;
			result.CC_AgentWork__c = record.Id;
			result.CC_Case__c = (String.isNotBlank(record.WorkItemId) && String.valueOf(record.WorkItemId).startsWith('500')) ? record.WorkItemId : null;
			result.CC_OmnichannelAvaiable__c = true;
			//eta, PAXIMPL-15845: copy values of Service Provider and Service Country Code from User
			result.CC_ServiceProvider__c = UserService.getServiceProvider();
			result.CC_ServiceCountryCode__c = UserService.getCountryCode();
		}

		return result;
	}

	/**
	 * @author dme
	 * @description Copy standard AgentWork record to related custom CC_AgentWorkCloned__c record
	 * @jira PARXIMPL-6734
	 */
	public static void copyAgentWorkData(List<AgentWork> agentWorks)
	{
		try
		{
			Map<Id, Id> agentWorkIdToAgentWorkClonedIdMap = new Map<Id, Id>();
			for (CC_AgentWorkCloned__c clonedRecord : [SELECT Id, CC_AgentWork__c FROM CC_AgentWorkCloned__c WHERE CC_AgentWork__c IN :agentWorks])
			{
				agentWorkIdToAgentWorkClonedIdMap.put(clonedRecord.CC_AgentWork__c, clonedRecord.Id);
			}

			List<CC_AgentWorkCloned__c> result = copyAgentWorks(agentWorks);
			for (CC_AgentWorkCloned__c agentWorkCloned : result)
			{
				agentWorkCloned.Id = agentWorkIdToAgentWorkClonedIdMap.get(agentWorkCloned.CC_AgentWork__c);
			}

			// PTS : SFLIT-1145: disabled triggers initialized it anyway), however we expect AgentWorkClonedTrigger trigger to run.
			TriggerTemplateV2.resetTriggerTemplateState();
			upsert result;
		}
		catch (Exception ex)
		{
			Logger.exception('Error during AgentWork cloning process', ex, new Map<Id, AgentWork>(agentWorks).keySet(), 'AgentWorkService.copyAgentWorkData');
		}
	}

	/**
	 * @author dme
	 * @descriptio Create custom or standard AgentWork record for case; records are needed for the reports
	 * @jira PARXIMPL-6734
	 */
	public static void createAgentWorkForInProgressCase(List<Case> inProgressCases)
	{
		// isk PARXIMPL-10587 Agent Work and Agent Work Cloned are not created for 3rd lvl agent and QA TL
		if (skipAgentWorkCreation || inProgressCases == null || inProgressCases.isEmpty() || (UserService.is3rdLevelAgent(UserService.contextUser.Id) || UserService.isQATeamLead(UserService.contextUser.Id)))
		{
			return;
		}

		System.debug('....createAgentWorkForInProgressCase: ' + inProgressCases.size());
		List<AgentWork> agentWorkList = new List<AgentWork>();
		List<CC_AgentWorkCloned__c> agentWorkClonedList = new List<CC_AgentWorkCloned__c>();

		Id serviceChannelId;
		Boolean isCorrectOmniChannelState = false;
		Set<Id> activeWorkItemIds = new Set<Id>();
		List<UserServicePresence> agentStatuses = [SELECT Id, IsAway, ServicePresenceStatusId FROM UserServicePresence WHERE UserId = :UserInfo.getUserId() AND IsCurrentState = TRUE];
		if (!agentStatuses.isEmpty() && !agentStatuses.get(0).IsAway)
		{
			// kma : PARXIMPL-10944 : Added Phone PresentStatus
			List<ServiceChannel> serviceChannels = [SELECT Id FROM ServiceChannel WHERE DeveloperName =: CC_CaseConstants.CASE_SERVICE_CHANNEL OR DeveloperName =: CC_CaseConstants.PHONE_SERVICE_CHANNEL ];
			if (!serviceChannels.isEmpty())
			{
				List<ServiceChannelStatus> serviceChannelStatuses = [SELECT Id,ServiceChannelId FROM ServiceChannelStatus WHERE ServiceChannelId IN :serviceChannels AND ServicePresenceStatusId = :agentStatuses.get(0).ServicePresenceStatusId];
				if (!serviceChannelStatuses.isEmpty())
				{
					serviceChannelId = serviceChannelStatuses.get(0).ServiceChannelId;
					isCorrectOmniChannelState = true;
					List<AgentWork> agentWorks = AgentWorkService.getActiveAgentWorksForCurrentUser();
					for (AgentWork agentWorkItem : agentWorks)
					{
						activeWorkItemIds.add(agentWorkItem.WorkItemId);
					}
				}
			}
		}

		System.debug('....isCorrectOmniChannelState: ' + isCorrectOmniChannelState);
		for (Case cs : inProgressCases)
		{
			if (!activeWorkItemIds.contains(cs.Id))
			{
				if (isCorrectOmniChannelState)
				{
					agentWorkList.add(new AgentWork(
						CC_ManuallyCreated__c = true,
						ServiceChannelId = serviceChannelId,
						UserId = UserInfo.getUserId(),
						WorkItemId = cs.Id,
						CapacityWeight = CC_Constants.MAX_WEIGHT_CAPACITY
					));
				}
				else
				{
					// kma : PARXIMPL-10944 : Improvment of logic
					DateTime now = DateTime.now();
					agentWorkClonedList.add(new CC_AgentWorkCloned__c(
						CC_AcceptDateTime__c = now,
						CC_CreatedById__c = UserInfo.getUserId(),
						CC_CreatedDate__c = now,
						CC_LastModifiedById__c = UserInfo.getUserId(),
						CC_LastModifiedDate__c = now,
						CC_OwnerId__c = UserInfo.getUserId(),
						CC_OwnerName__c = UserInfo.getName(),
						CC_RequestDateTime__c = now,
						CC_Status__c = 'Opened',
						CC_UnitsOfCapacity__c = CC_Constants.MAX_WEIGHT_CAPACITY,
						CC_UserId__c = UserInfo.getUserId(),
						CC_WorkItemId__c = cs.Id,
						CC_Case__c = cs.Id,
						CC_OmnichannelAvaiable__c = false,
						CC_ServiceProvider__c = UserService.getServiceProvider(),
						CC_ServiceCountryCode__c = UserService.getCountryCode()
					));
				}
			}
		}

		// isk PARXIMPL-10338 we need that agentWorkTrigger was executed after update case in merge scenario
		TriggerTemplateV2.resetTriggerTemplateState();

		if (!agentWorkList.isEmpty())
		{
			insert agentWorkList;
		}

		if (!agentWorkClonedList.isEmpty())
		{
			insert agentWorkClonedList;
		}
	}

	/**
	 * @author PTS
	 * @description  Calculates the sum of Active Time &  sum of Handle Time from related Agent Work Items and update to the respective case records.
	 * @jira SFLIT-1145
	 */
	public static void calculateCaseActiveTimeAndHandleTime(List<sObject> agentWorks, Map<Id, sObject> oldMap){
		Set<id> caseIds = new Set<id>();
		Id caseId;
		for(SObject awc : TriggerUtil.getModifiedObjects(new List<String> {'CC_ActiveTime__c', 'CC_HandleTime__c', 'CC_Case__c'}, agentWorks, oldMap)){
			caseId = (Id) awc.get('CC_Case__c');
			if(caseId != null){
					caseIds.add(caseId);
			}
		}
		calculateCaseActiveTimeAndHandleTime(caseIds);
	}

	/**
	 * @author PTS
	 * @description  Calculates the sum of Active Time &  sum of Handle Time from related Agent Work Items and update to the respective case records.
	 * @jira SFLIT-1145
	 */
	public static void calculateCaseActiveTimeAndHandleTime(Set<Id> caseIds){
			if(caseIds.size() > 0){
				try{
					List<Case> updateCases = new List<Case>();
					for (AggregateResult ar : [SELECT CC_Case__c, SUM(CC_ActiveTime__c) totalActiveTime, SUM(CC_HandleTime__c) totalHandleTime
																		FROM CC_AgentWorkCloned__c
																		WHERE CC_Case__c IN:caseIds
																		GROUP BY CC_Case__c]){
							updateCases.add(new Case( Id = (Id) ar.get('CC_Case__c'),
																				CC_ActiveTime__c = (Decimal) ar.get('totalActiveTime'),
																				CC_HandleTime__c = (Decimal) ar.get('totalHandleTime')
																			));
					}
					Boolean previousFlagValue = TriggerTemplateV2.allTriggersDisabled;
          TriggerTemplateV2.allTriggersDisabled = true;
					update updateCases;
					TriggerTemplateV2.allTriggersDisabled = previousFlagValue;
					TriggerTemplateV2.resetTriggerTemplateState();
				}
				catch (Exception ex){
					Logger.exception('Error during Aggragating Case Active Time &  Handle Time', ex, caseIds, 'AgentWorkService.calculateCaseActiveTimeAndHandleTime');
				}
			}
	}

}