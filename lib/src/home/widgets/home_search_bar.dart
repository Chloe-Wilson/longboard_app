import 'package:flutter/material.dart';

import '../helpers/search_helpers.dart';

class HomeSearchBar extends StatelessWidget {
  const HomeSearchBar({
    super.key,
    required this.searchController,
    required this.searchFocusNode,
    required this.isSearchingLocation,
    required this.searchSuggestions,
    required this.onSearchTextChanged,
    required this.onSearchSubmitted,
    required this.onSuggestionSelected,
  });

  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final bool isSearchingLocation;
  final List<SearchSuggestion> searchSuggestions;
  final ValueChanged<String> onSearchTextChanged;
  final VoidCallback onSearchSubmitted;
  final ValueChanged<SearchSuggestion> onSuggestionSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.white.withAlpha(153),
          elevation: 4,
          borderRadius: BorderRadius.circular(28.0),
          child: TextField(
            controller: searchController,
            focusNode: searchFocusNode,
            textInputAction: TextInputAction.search,
            onChanged: onSearchTextChanged,
            onSubmitted: (_) => onSearchSubmitted(),
            decoration: InputDecoration(
              hintText: 'Search location',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: isSearchingLocation
                  ? const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28.0),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white.withAlpha(140),
            ),
          ),
        ),
        if (searchSuggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8.0),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(243),
              borderRadius: BorderRadius.circular(12.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(38),
                  blurRadius: 12.0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: searchSuggestions.length,
              itemBuilder: (context, index) {
                final suggestion = searchSuggestions[index];
                return ListTile(
                  title: Text(suggestion.label),
                  onTap: () => onSuggestionSelected(suggestion),
                );
              },
            ),
          ),
      ],
    );
  }
}
