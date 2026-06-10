import '../models/models.dart';

/// Booth booking rules
/// ===================
/// These helper functions support the "prevent adjacent competitors" rule.
/// The rule is switched on or off by the organizer for each exhibition
/// (the `preventAdjacentCompetitors` field). When it is ON, an exhibitor
/// is not allowed to book a booth that sits right next to a booth already
/// taken by a DIFFERENT company (a competitor).

/// Returns true if two booth boxes OVERLAP (cover some of the same area).
/// Used by the Admin layout editor to stop booths being dragged or
/// resized on top of each other. Booths that only touch edges do NOT
/// count as overlapping.
bool boothsOverlap(Booth a, Booth b) {
  return a.x < b.x + b.width &&
      b.x < a.x + a.width &&
      a.y < b.y + b.height &&
      b.y < a.y + a.height;
}

/// Returns true if booth [a] and booth [b] are physically next to each
/// other on the floor plan - either left/right neighbours or top/bottom
/// neighbours. Booths that only touch at a corner (diagonal) are NOT
/// counted as adjacent.
bool areBoothsAdjacent(Booth a, Booth b) {
  // How close two booths must be to count as "next to each other".
  // The seeded grid leaves a 20px gap between booths, so 40px safely
  // catches real neighbours without catching far-away booths.
  const double maxGap = 40.0;

  // The four edges of each booth box.
  final aLeft = a.x, aRight = a.x + a.width;
  final aTop = a.y, aBottom = a.y + a.height;
  final bLeft = b.x, bRight = b.x + b.width;
  final bTop = b.y, bBottom = b.y + b.height;

  // Do the two booths share space on the vertical axis? (same row)
  final shareRows = aTop < bBottom && bTop < aBottom;
  // Do the two booths share space on the horizontal axis? (same column)
  final shareCols = aLeft < bRight && bLeft < aRight;

  // Gap between the two booths left-to-right (0 if they touch/overlap).
  double horizontalGap;
  if (aRight <= bLeft) {
    horizontalGap = bLeft - aRight; // b is to the right of a
  } else if (bRight <= aLeft) {
    horizontalGap = aLeft - bRight; // b is to the left of a
  } else {
    horizontalGap = 0; // they overlap horizontally
  }

  // Gap between the two booths top-to-bottom (0 if they touch/overlap).
  double verticalGap;
  if (aBottom <= bTop) {
    verticalGap = bTop - aBottom; // b is below a
  } else if (bBottom <= aTop) {
    verticalGap = aTop - bBottom; // b is above a
  } else {
    verticalGap = 0; // they overlap vertically
  }

  // Left/right neighbour: in the same row AND only a small gap apart.
  final sideBySide = shareRows && horizontalGap <= maxGap;
  // Top/bottom neighbour: in the same column AND only a small gap apart.
  final stacked = shareCols && verticalGap <= maxGap;

  return sideBySide || stacked;
}

/// Checks whether the [candidate] booth sits next to a booth that is
/// already taken by a competitor (a company different from [myCompany]).
///
/// [allBooths]    - every booth in the exhibition.
/// [boothCompany] - a map of boothId -> the company that took that booth.
/// [myCompany]    - the current exhibitor's own company name.
///
/// Returns the competitor's company name if there is a conflict, or null
/// if the candidate booth is safe to select.
String? competitorNextTo({
  required Booth candidate,
  required List<Booth> allBooths,
  required Map<String, String> boothCompany,
  required String myCompany,
}) {
  final mine = myCompany.trim().toLowerCase();

  for (final other in allBooths) {
    if (other.id == candidate.id) continue; // skip the booth itself

    final company = boothCompany[other.id];
    if (company == null) continue; // this booth is free -> no conflict
    if (company.trim().toLowerCase() == mine) continue; // my own company

    // A different company holds this booth. If it is adjacent, block it.
    if (areBoothsAdjacent(candidate, other)) {
      return company; // a competitor is right next door
    }
  }
  return null; // no competitor nearby -> safe to select
}
