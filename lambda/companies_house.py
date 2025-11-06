"""
Companies House API Integration
Fetches company information from the UK Companies House API
"""

import requests
from typing import Dict, Optional
import re


# Company number prefix mappings
COMPANY_TYPE_PREFIXES = {
    # England and Wales
    '': 'Private Limited Company',
    'OC': 'Limited Liability Partnership',
    'LP': 'Limited Partnership',
    'FC': 'Overseas Company',
    'AC': 'Assurance Company',
    'RC': 'Royal Charter Company',
    'CE': 'Charitable Incorporated Organisation',
    'ZC': 'Unregistered Company',

    # Scotland
    'SC': 'Private Limited Company',
    'SO': 'Limited Liability Partnership',
    'SL': 'Limited Partnership',
    'SF': 'Overseas Company',
    'SA': 'Assurance Company',
    'SR': 'Royal Charter Company',
    'CS': 'Scottish Charitable Incorporated Organisation',
    'SZ': 'Unregistered Company',

    # Northern Ireland
    'NI': 'Private Limited Company',
    'NC': 'Limited Liability Partnership',
    'NO': 'Limited Liability Partnership',
    'NL': 'Limited Partnership',
    'NR': 'Royal Charter Company',

    # UK Establishment
    'BR': 'UK Establishment',
}

JURISDICTION_PREFIXES = {
    'SC': 'Scotland',
    'SO': 'Scotland',
    'SL': 'Scotland',
    'SF': 'Scotland',
    'SA': 'Scotland',
    'SR': 'Scotland',
    'CS': 'Scotland',
    'SZ': 'Scotland',

    'NI': 'Northern Ireland',
    'NC': 'Northern Ireland',
    'NO': 'Northern Ireland',
    'NL': 'Northern Ireland',
    'NR': 'Northern Ireland',
}


class CompaniesHouseClient:
    """Client for Companies House API"""

    BASE_URL = "https://api.company-information.service.gov.uk"

    def __init__(self, api_key: Optional[str] = None):
        """
        Initialize Companies House client

        Args:
            api_key: Companies House API key (optional, free tier available)
        """
        self.api_key = api_key
        self.session = requests.Session()
        if api_key:
            # API key is used as basic auth username with no password
            self.session.auth = (api_key, '')

    def get_company_details(self, company_number: str) -> Dict:
        """
        Fetch company details from Companies House

        Args:
            company_number: UK company registration number

        Returns:
            Dictionary with company details

        Raises:
            Exception if company not found or API error
        """
        # Clean company number (remove spaces and convert to uppercase)
        company_number = company_number.replace(' ', '').upper()

        url = f"{self.BASE_URL}/company/{company_number}"

        response = self.session.get(url)

        if response.status_code == 404:
            raise ValueError(f"Company number {company_number} not found")
        elif response.status_code != 200:
            raise Exception(f"Companies House API error: {response.status_code} - {response.text}")

        data = response.json()

        # Extract and format the information we need
        return self._parse_company_data(data)

    def _parse_company_data(self, data: Dict) -> Dict:
        """Parse Companies House API response into our format"""

        company_number = data.get('company_number', '')
        company_name = data.get('company_name', '')

        # Get registered office address
        address_data = data.get('registered_office_address', {})
        address = self._format_address(address_data)

        # Infer company type and jurisdiction from company number
        company_type = self._infer_company_type(company_number)
        jurisdiction = self._infer_jurisdiction(company_number)

        # Get actual company type from API if available
        api_company_type = data.get('type', '')

        return {
            'company_number': company_number,
            'company_name': company_name,
            'registered_office_address': address,
            'company_type': company_type,
            'company_type_api': api_company_type,
            'jurisdiction': jurisdiction,
            'company_status': data.get('company_status', ''),
            'date_of_creation': data.get('date_of_creation', ''),
            'raw_data': data  # Include full response for reference
        }

    def _format_address(self, address_data: Dict) -> str:
        """Format address from Companies House data into single string"""
        parts = []

        # Add address line components
        for key in ['address_line_1', 'address_line_2', 'care_of', 'po_box']:
            if address_data.get(key):
                parts.append(address_data[key])

        # Add locality/town
        if address_data.get('locality'):
            parts.append(address_data['locality'])

        # Add region
        if address_data.get('region'):
            parts.append(address_data['region'])

        # Add postal code
        if address_data.get('postal_code'):
            parts.append(address_data['postal_code'])

        # Add country
        if address_data.get('country'):
            parts.append(address_data['country'])

        return ', '.join(parts)

    def _infer_company_type(self, company_number: str) -> str:
        """Infer company type from company number prefix"""
        prefix = self._extract_prefix(company_number)
        return COMPANY_TYPE_PREFIXES.get(prefix, 'Private Limited Company')

    def _infer_jurisdiction(self, company_number: str) -> str:
        """Infer jurisdiction from company number prefix"""
        prefix = self._extract_prefix(company_number)
        return JURISDICTION_PREFIXES.get(prefix, 'England and Wales')

    def _extract_prefix(self, company_number: str) -> str:
        """Extract alphabetic prefix from company number"""
        match = re.match(r'^([A-Z]+)', company_number)
        return match.group(1) if match else ''


def search_company_by_name(company_name: str, api_key: Optional[str] = None) -> list:
    """
    Search for companies by name

    Args:
        company_name: Company name to search for
        api_key: Companies House API key

    Returns:
        List of matching companies with basic details
    """
    client = CompaniesHouseClient(api_key)
    url = f"{client.BASE_URL}/search/companies"

    response = client.session.get(url, params={'q': company_name})

    if response.status_code != 200:
        raise Exception(f"Companies House search error: {response.status_code}")

    data = response.json()
    items = data.get('items', [])

    results = []
    for item in items:
        results.append({
            'company_number': item.get('company_number'),
            'company_name': item.get('title'),
            'company_type': item.get('company_type'),
            'company_status': item.get('company_status'),
            'address': item.get('address_snippet'),
        })

    return results


# Example usage and testing
if __name__ == '__main__':
    # Test with a known company (Apple UK)
    client = CompaniesHouseClient()

    try:
        # Test 1: Standard UK company
        details = client.get_company_details('01234567')
        print("Test 1 - Standard company:")
        print(f"  Name: {details['company_name']}")
        print(f"  Number: {details['company_number']}")
        print(f"  Type: {details['company_type']}")
        print(f"  Jurisdiction: {details['jurisdiction']}")
        print(f"  Address: {details['registered_office_address']}")
        print()

        # Test 2: Scottish company (SC prefix)
        details = client.get_company_details('SC123456')
        print("Test 2 - Scottish company:")
        print(f"  Jurisdiction: {details['jurisdiction']}")
        print()

        # Test 3: LLP (OC prefix)
        details = client.get_company_details('OC123456')
        print("Test 3 - LLP:")
        print(f"  Type: {details['company_type']}")
        print()

    except Exception as e:
        print(f"Error: {e}")
