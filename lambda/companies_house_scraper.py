"""
Companies House Web Scraper
Scrapes company information from the public Companies House website
NO API KEY REQUIRED - uses public data
"""

import re
from typing import Dict, Optional
from urllib.parse import quote

try:
    import requests
    from bs4 import BeautifulSoup
except ImportError:
    print("Warning: requests or beautifulsoup4 not installed")


# Company number prefix mappings (same as before)
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


class CompaniesHouseScraper:
    """Scraper for Companies House public website"""

    BASE_URL = "https://find-and-update.company-information.service.gov.uk"

    def __init__(self):
        """Initialize scraper"""
        self.session = requests.Session()
        # Set user agent to look like a browser
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
        })

    def get_company_details(self, company_number: str) -> Dict:
        """
        Scrape company details from public Companies House website

        Args:
            company_number: UK company registration number

        Returns:
            Dictionary with company details

        Raises:
            Exception if company not found or scraping error
        """
        # Clean company number
        company_number = company_number.replace(' ', '').upper()

        # Build URL
        url = f"{self.BASE_URL}/company/{company_number}"

        print(f"Fetching: {url}")

        # Fetch page
        response = self.session.get(url)

        if response.status_code == 404:
            raise ValueError(f"Company number {company_number} not found")
        elif response.status_code != 200:
            raise Exception(f"Error fetching company page: {response.status_code}")

        # Parse HTML
        soup = BeautifulSoup(response.content, 'html.parser')

        # Extract company data
        return self._parse_company_page(soup, company_number)

    def _parse_company_page(self, soup: BeautifulSoup, company_number: str) -> Dict:
        """Parse company details from HTML page"""

        # Get company name (from h1 or title)
        company_name = None
        h1 = soup.find('h1', class_='heading-xlarge')
        if h1:
            company_name = h1.text.strip()

        if not company_name:
            # Fallback: from page title
            title = soup.find('title')
            if title:
                # Title format: "COMPANY NAME - Overview - Find and update company information"
                company_name = title.text.split(' - ')[0].strip()

        # Get registered office address
        address = self._extract_address(soup)

        # Get company type from page
        company_type_from_page = self._extract_company_type(soup)

        # Infer company type and jurisdiction from prefix
        company_type_inferred = self._infer_company_type(company_number)
        jurisdiction = self._infer_jurisdiction(company_number)

        # Prefer inferred type, fallback to page type
        company_type = company_type_inferred if company_type_inferred else company_type_from_page

        # Get company status
        status = self._extract_status(soup)

        return {
            'company_number': company_number,
            'company_name': company_name,
            'registered_office_address': address,
            'company_type': company_type,
            'jurisdiction': jurisdiction,
            'company_status': status,
            'source': 'web_scrape'
        }

    def _extract_address(self, soup: BeautifulSoup) -> str:
        """Extract registered office address from page"""

        # Look for address in various possible locations
        # Method 1: Look for dl with address
        dl = soup.find('dl', class_='column-three-quarters')
        if dl:
            dt_elements = dl.find_all('dt')
            for dt in dt_elements:
                if 'Registered office address' in dt.text or 'registered office' in dt.text.lower():
                    dd = dt.find_next_sibling('dd')
                    if dd:
                        # Get all text, join with commas
                        address_parts = [line.strip() for line in dd.stripped_strings]
                        return ', '.join(address_parts)

        # Method 2: Look for specific ID or class
        address_div = soup.find('div', id='registered-office-address')
        if address_div:
            address_parts = [line.strip() for line in address_div.stripped_strings]
            return ', '.join(address_parts)

        # Method 3: Look for any div with address-like content
        # This is a fallback
        all_text = soup.get_text()
        address_match = re.search(r'Registered office address\s*([A-Z0-9].*?)(?:Company status|Date of|Accounts)',
                                  all_text, re.DOTALL)
        if address_match:
            address = address_match.group(1).strip()
            # Clean up whitespace
            address = re.sub(r'\s+', ' ', address)
            return address

        return "Address not found"

    def _extract_company_type(self, soup: BeautifulSoup) -> str:
        """Extract company type from page"""

        # Look for company type in dl elements
        dl = soup.find('dl')
        if dl:
            dt_elements = dl.find_all('dt')
            for dt in dt_elements:
                if 'Company type' in dt.text:
                    dd = dt.find_next_sibling('dd')
                    if dd:
                        return dd.text.strip()

        return "Private Limited Company"  # Default

    def _extract_status(self, soup: BeautifulSoup) -> str:
        """Extract company status from page"""

        dl = soup.find('dl')
        if dl:
            dt_elements = dl.find_all('dt')
            for dt in dt_elements:
                if 'Company status' in dt.text:
                    dd = dt.find_next_sibling('dd')
                    if dd:
                        return dd.text.strip()

        return "Active"  # Default

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


# Example usage
if __name__ == '__main__':
    scraper = CompaniesHouseScraper()

    # Test with Cloudscaler
    try:
        print("Testing Companies House Web Scraper")
        print("=" * 70)
        print()

        details = scraper.get_company_details('11515460')

        print("✓ Company found:")
        print(f"  Name: {details['company_name']}")
        print(f"  Number: {details['company_number']}")
        print(f"  Type: {details['company_type']}")
        print(f"  Jurisdiction: {details['jurisdiction']}")
        print(f"  Address: {details['registered_office_address']}")
        print(f"  Status: {details['company_status']}")
        print()

        # Test Scottish company
        print("Testing Scottish company (SC prefix)...")
        details = scraper.get_company_details('SC234567')
        print(f"  Jurisdiction: {details['jurisdiction']} (inferred from SC prefix)")
        print()

    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
