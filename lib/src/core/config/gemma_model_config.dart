/// On-device Gemma 4 model URLs (LiteRT-LM `.litertlm` for Android).
library;

const kGemma4Repo = 'litert-community/gemma-4-E4B-it-litert-lm';
const kGemma4E2BRepo = 'litert-community/gemma-4-E2B-it-litert-lm';

/// Gemma 4 E4B — flagship (~3 GB). Public, no HuggingFace token.
const kGemma4E4BLitertLmFile = 'gemma-4-E4B-it.litertlm';
const kGemma4E4BLitertLmUrl =
    'https://huggingface.co/$kGemma4Repo/resolve/main/$kGemma4E4BLitertLmFile';

/// Gemma 4 E2B — smaller Gemma 4 (~3 GB, often faster on mid phones).
const kGemma4E2BLitertLmFile = 'gemma-4-E2B-it.litertlm';
const kGemma4E2BLitertLmUrl =
    'https://huggingface.co/$kGemma4E2BRepo/resolve/main/$kGemma4E2BLitertLmFile';

/// Default download target in Settings → EDGE.
const kDefaultGemma4Url = kGemma4E4BLitertLmUrl;

const kGemma4E4BApproxMb = 3000;
const kGemma4E2BApproxMb = 3000;
