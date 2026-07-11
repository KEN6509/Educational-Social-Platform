# Text-Only Post Cards Design

## Behavior

- A post with no attached images is a text-only post.
- Text-only feed cards use the same card colors, border, radius, spacing language, author row, like action, status badge, and navigation behavior as image posts.
- Their structure is `title -> truncated content -> author avatar/name/like count`.
- The entire card stays at a fixed 3:4 width-to-height ratio.
- The title wraps fully. Content consumes the remaining space and truncates before the fixed author row.
- No image placeholder, decorative illustration, or fake media surface is shown.

## Post Detail And Editing

- Text-only post details omit the image carousel and pagination dots.
- If editing removes every attached image, the refreshed post model has an empty image list and immediately switches to the text-only card/detail presentation.
- Adding images to a text-only post switches it back to the normal image-card presentation.

## Loading

- Skeleton loaders only represent genuinely pending data retrieval, especially under weak or unavailable connectivity.
- Skeletons must not be deliberately delayed and must never replace content already available in memory or cache.

## Verification

- Model tests cover text-only classification.
- Widget tests cover the fixed 3:4 layout, visible title/content/author metadata, and absence of the image placeholder.
- Existing analyzer and full Flutter tests must remain clean.
