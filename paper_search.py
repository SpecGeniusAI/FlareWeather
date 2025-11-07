"""
Search for research papers using EuropePMC REST API.
"""

import requests
from typing import List, Dict, Optional
import time


def search_papers(symptom: str, weather_factor: str, max_results: int = 3) -> List[Dict[str, str]]:
    """
    Search EuropePMC for open-access articles related to symptom and weather factor.
    
    Args:
        symptom: Symptom type (e.g., "joint pain", "headache")
        weather_factor: Weather factor (e.g., "barometric pressure", "temperature")
        max_results: Maximum number of results to return (default: 3)
        
    Returns:
        List of dictionaries with paper information:
        [
            {
                "title": str,
                "abstract": str,
                "journal": str,
                "year": str,
                "authors": str,
                "source": str  # PMCID or ID
            },
            ...
        ]
    """
    try:
        # Construct query: "symptom AND weather_factor"
        query = f"{symptom} AND {weather_factor}"
        
        # EuropePMC REST API endpoint
        base_url = "https://www.ebi.ac.uk/europepmc/webservices/rest/search"
        
        # Parameters
        params = {
            "query": query,
            "format": "json",
            "pageSize": max_results,
            "synonym": "true"  # Use synonym expansion
        }
        
        # Make request
        response = requests.get(base_url, params=params, timeout=10)
        response.raise_for_status()
        
        data = response.json()
        
        # Debug: check response structure
        if "resultList" not in data:
            print(f"⚠️  No 'resultList' in response. Keys: {list(data.keys())}")
            return []
        
        # Extract results
        papers = []
        results_list = []
        
        # Handle different response structures
        result_list_data = data["resultList"]
        if isinstance(result_list_data, dict) and "result" in result_list_data:
            results_list = result_list_data["result"]
        elif isinstance(result_list_data, list):
            results_list = result_list_data
        else:
            print(f"⚠️  Unexpected resultList structure: {type(result_list_data)}")
            return []
        
        if not isinstance(results_list, list):
            print(f"⚠️  results_list is not a list: {type(results_list)}")
            results_list = []
        
        
        for paper in results_list[:max_results]:
            # Extract title
            title = paper.get("title", "")
            if not title:
                print(f"⚠️  Skipping paper with no title: {paper.get('id', 'unknown')}")
                continue
                
            # Extract abstract (may be in different fields)
            abstract = paper.get("abstractText", "") or paper.get("abstract", "")
            
            # Extract journal
            journal = paper.get("journalTitle", "") or paper.get("journal", "") or "Unknown journal"
            
            # Extract year
            pub_year = paper.get("pubYear", "")
            if not pub_year:
                # Try to extract from publication date
                pub_date = paper.get("firstPublicationDate", "") or paper.get("pubDate", "")
                if pub_date:
                    pub_year = pub_date.split("-")[0] if "-" in pub_date else pub_date[:4]
            
            # Extract authors
            author_list = paper.get("authorString", "")
            if not author_list:
                # Try to get from author list
                author_list_data = paper.get("authorList", {})
                if isinstance(author_list_data, dict) and "author" in author_list_data:
                    authors = author_list_data["author"]
                    if isinstance(authors, list):
                        author_names = []
                        for a in authors[:3]:
                            if isinstance(a, dict):
                                name = a.get("fullName", "") or a.get("lastName", "")
                                if name:
                                    author_names.append(name)
                        if author_names:
                            author_list = ", ".join(author_names)
                            if len(authors) > 3:
                                author_list += " et al."
            
            if not author_list:
                author_list = "Unknown authors"
            
            # Extract source (PMCID preferred, fallback to ID)
            source = paper.get("pmcid", "") or paper.get("id", "")
            if not source:
                # Try other ID fields
                source = paper.get("pmid", "") or paper.get("doi", "")
            
            # Format source nicely
            if source.startswith("PMC"):
                source_display = source
            elif source.startswith("PMID"):
                source_display = source
            elif source:
                # If it's just a number, prefix with PMCID
                source_display = f"PMC{source}" if source.isdigit() else source
            else:
                source_display = "Unknown"
            
            # Add paper if we have at least a title
            papers.append({
                "title": title,
                "abstract": abstract or "No abstract available",
                "journal": journal,
                "year": pub_year or "Unknown",
                "authors": author_list,
                "source": source_display
            })
        
        return papers
        
    except requests.exceptions.RequestException as e:
        print(f"Error searching EuropePMC: {e}")
        return []
    except Exception as e:
        print(f"Error processing EuropePMC results: {e}")
        return []


def format_papers_for_prompt(papers: List[Dict[str, str]]) -> str:
    """
    Format papers into a text block for prompt injection.
    
    Args:
        papers: List of paper dictionaries
        
    Returns:
        Formatted string with paper information
    """
    if not papers:
        return ""
    
    formatted = []
    for paper in papers:
        title = paper.get("title", "No title")
        journal = paper.get("journal", "Unknown journal")
        year = paper.get("year", "Unknown")
        abstract = paper.get("abstract", "")
        source = paper.get("source", "")
        
        # Format: Title (Journal, Year): Abstract
        entry = f"{title} ({journal}, {year})"
        if source:
            entry += f" [Source: {source}]"
        entry += f": {abstract}"
        
        formatted.append(entry)
    
    return "\n\n".join(formatted)


if __name__ == "__main__":
    # Test search
    print("Testing paper search...")
    results = search_papers("joint pain", "barometric pressure", max_results=3)
    
    print(f"Found {len(results)} papers:\n")
    for i, paper in enumerate(results, 1):
        print(f"{i}. {paper['title']}")
        print(f"   Journal: {paper['journal']} ({paper['year']})")
        print(f"   Authors: {paper['authors']}")
        print(f"   Source: {paper['source']}")
        print(f"   Abstract: {paper['abstract'][:200]}...")
        print()

