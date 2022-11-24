/**
*	Class to handle xml responses.
*
*	@author yle, ach, dme
*	@copyright PARX
*/
public with sharing class XMLResponseHandler
{

	public static String walkThrough(DOM.XMLNode node, String tagName)
	{
		String result = '';
		if (node.getNodeType() == DOM.XMLNodeType.ELEMENT)
		{
			if (node.getText().trim() != '')
			{
				String nName = node.getName();
				if(nName == tagName)
				{
					return node.getText().trim();
				}
			}
			if (node.getAttributeCount() > 0)
			{
				for (Integer i = 0; i< node.getAttributeCount(); i++ )
				{
					result += '';
				}
			}
			for (Dom.XMLNode child: node.getChildElements())
			{
				result += walkThrough(child, tagName);
			}
			return result;
		}
		return '';
	}

	public static String getNodeValue(DOM.XMLNode node, String tagName)
	{
		String result = '';
		if (node.getNodeType() == DOM.XMLNodeType.ELEMENT)
		{
			DOM.XmlNode childNode = node.getChildElement(tagName, null);
			if (childNode != null)
			{
				result = childNode.getText();
			}
		}

		return result;
	}

	public static DOM.XMLNode findNodeByName(DOM.XMLNode node, String tagName)
	{
		DOM.XMLNode result = null;
		if (node.getNodeType() == DOM.XMLNodeType.ELEMENT)
		{
			if (node.getName() == tagName)
			{
				return node;
			}
			
			for (Dom.XMLNode child: node.getChildElements())
			{
				result = findNodeByName(child, tagName);
				if (result != null)
				{
					return result;
				}
			}
			return result;
		}
		return result;
	}


	public static Set<DOM.XMLNode> findNodesByName(DOM.XMLNode node, String tagName)
	{
		Set<DOM.XMLNode> result = new Set<DOM.XMLNode>();
		if (node.getNodeType() == DOM.XMLNodeType.ELEMENT)
		{
			if (node.getName() == tagName)
			{
				return new Set<DOM.XMLNode>{node};
			}
			
			for (Dom.XMLNode child: node.getChildElements())
			{
				result.addAll(findNodesByName(child, tagName));
			}
		}
		return result;
	}

	public static String getValueByTag(String tagName, String xmlstring)
	{
		DOM.Document xmlDOC = new DOM.Document();
		xmlDOC.load(xmlstring);
		return walkThrough(xmlDOC.getRootElement(), tagName);
	}

	public static String getValueByTag(String tagName, Dom.Document doc)
	{
		return walkThrough(doc.getRootElement(), tagName);
	}

	public static Set<String> getArrayValueByTag(String tagName, String xmlstring)
	{
		DOM.Document xmlDOC = new DOM.Document();
		xmlDOC.load(xmlstring);
		Set<String> result = getArrayValueWalkThrough(xmlDOC.getRootElement(), tagName, new Set<String>{});
		result.remove(null);
		return result;
	}

	/**
	*	Get changed field value, for example for customer_last_name it will find Ortmann here:
	*   <getChangedTicketDataResult><changed_ticket_data_details><TicketChange><field>customer_last_name</field><timestamp>2017-09-11T09:11:21</timestamp><value>Ortmann</value></TicketChange></changed_ticket_data_details>';
	*   //dme : PARXIMPL-1977 : Updated body parse logic to handle nodes with different timestamp
	*/
	public static List<DOM.XMLNode> getChangedFieldValue(String spFieldName, String xmlstring)
	{
		List<DOM.XmlNode> result = new List<DOM.XmlNode>();
		DOM.Document xmlDOC = new DOM.Document();
		xmlDOC.load(xmlstring);
		DOM.XMLNode detailsNode = findNodeByName(xmlDOC.getRootElement(), 'changed_ticket_data_details');
		for (Dom.XMLNode child: detailsNode.getChildElements())
		{
			if (child.getName() == 'TicketChange')
			{
				String fieldValue = walkThrough(child, 'field');
				if (fieldValue == spFieldName)
				{
					result.add(child);
				}
			}
		}

		return result;
	}

	/**
	*	Get array of values, for example: 
	*	<document_key><q1:string xmlns:q1="http://schemas.microsoft.com/2003/10/Serialization/Arrays">645c2933-b764-413f-b9de-fb691c445619</q1:string>
	*	<q2:string xmlns:q2="http://schemas.microsoft.com/2003/10/Serialization/Arrays">xxxx-222222</q2:string></document_key>
	*	Result will be {'645c2933-b764-413f-b9de-fb691c445619', 'xxxx-222222'}
	*/
	public static Set<String> getArrayValueWalkThrough(DOM.XMLNode node, String tagName, Set<String> parentTags)
	{
		Set<String> result = new Set<String>();
		if (node.getNodeType() == DOM.XMLNodeType.ELEMENT)
		{
			parentTags.add(node.getName());
			if (node.getText().trim() != '')
			{
				if(parentTags.contains(tagName))
				{
					return new Set<String>{node.getText().trim()};
				}
			}
			for (Dom.XMLNode child: node.getChildElements())
			{
				result.addAll(getArrayValueWalkThrough(child, tagName, parentTags.clone()));
			}
		}
		return result;
	}
	
	/**
	*	Get set of same tags, for example: 
	*	<Ticketstatus><q1>test</q1></Ticketstatus><Ticketstatus><q1>test2</q1></Ticketstatus>
	*	Result will be {'<Ticketstatus><q1>test</q1></Ticketstatus>', '<Ticketstatus><q1>test2</q1></Ticketstatus>'}
	*/
	public static Set<DOM.XMLNode> getSameTags(String tagName, String xmlstring)
	{
		DOM.Document xmlDOC = new DOM.Document();
		xmlDOC.load(xmlstring);
		Set<DOM.XMLNode> result = findNodesByName(xmlDOC.getRootElement(), tagName);
		result.remove(null);
		return result;
	}
}