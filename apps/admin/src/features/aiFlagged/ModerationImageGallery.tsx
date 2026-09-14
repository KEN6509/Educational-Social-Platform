import { useState } from 'react';

type ModerationImageGalleryProps = {
  imageUrls: string[];
};

export function ModerationImageGallery({ imageUrls }: ModerationImageGalleryProps) {
  const [failed, setFailed] = useState<Set<string>>(() => new Set());
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);

  if (imageUrls.length === 0) {
    return <p className="mt-3 text-sm text-slate-500">Image no longer available.</p>;
  }

  return (
    <>
      <div className="mt-3 grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
        {imageUrls.map((url, index) => failed.has(url) ? (
          <div
            aria-label={`Moderated image ${index + 1} unavailable`}
            className="grid min-h-40 place-items-center rounded-lg border border-dashed border-slate-300 bg-slate-50 p-4 text-center text-sm text-slate-500"
            key={url}
          >
            Image no longer available.
          </div>
        ) : (
          <button
            aria-label={`Enlarge moderated image ${index + 1}`}
            className="overflow-hidden rounded-lg border border-slate-200 bg-slate-50 text-left focus:outline-none focus:ring-2 focus:ring-cyan-500"
            key={url}
            onClick={() => setPreviewUrl(url)}
            type="button"
          >
            <img
              alt="Moderated post attachment"
              className="max-h-96 w-full object-contain"
              onError={() => setFailed((current) => new Set(current).add(url))}
              src={url}
            />
          </button>
        ))}
      </div>

      {previewUrl ? (
        <div
          aria-label="Moderated image preview"
          aria-modal="true"
          className="fixed inset-0 z-50 grid place-items-center bg-slate-950/80 p-6"
          onClick={(event) => {
            if (event.target === event.currentTarget) setPreviewUrl(null);
          }}
          role="dialog"
        >
          <button
            aria-label="Close image preview"
            className="absolute right-6 top-6 rounded-lg bg-white px-4 py-2 font-bold text-slate-800"
            onClick={() => setPreviewUrl(null)}
            type="button"
          >
            Close
          </button>
          <img
            alt="Enlarged moderated post attachment"
            className="max-h-[90vh] max-w-[90vw] object-contain"
            onError={() => {
              setFailed((current) => new Set(current).add(previewUrl));
              setPreviewUrl(null);
            }}
            src={previewUrl}
          />
        </div>
      ) : null}
    </>
  );
}
