'use strict';
const el = id => document.getElementById(id);
let imageURL;
function summary() {
  const business = el('business').value.trim() || 'Your business';
  const provider = document.querySelector('input[name="provider"]:checked').value;
  el('caption').textContent = `${business} · ${el('slot').value || 'Select a billboard'} · Inside LASU`;
  el('summary').textContent = `${el('duration').value}-day preview · ${provider} preferred · Pricing to be announced`;
}
for (const id of ['business', 'slot', 'duration']) el(id).addEventListener('input', summary);
for (const input of document.querySelectorAll('input[name="provider"]')) input.addEventListener('change', summary);
el('artwork').addEventListener('change', async event => {
  const file = event.target.files[0];
  el('error').textContent = '';
  el('preview').hidden = true;
  el('placeholder').hidden = false;
  if (imageURL) URL.revokeObjectURL(imageURL);
  if (!file) return;
  if (!['image/jpeg', 'image/png', 'image/webp'].includes(file.type) || file.size > 5 * 1024 * 1024) {
    el('error').textContent = 'Choose a JPG, PNG or WebP image smaller than 5 MB.';
    event.target.value = '';
    return;
  }
  imageURL = URL.createObjectURL(file);
  const image = el('preview');
  image.src = imageURL;
  try {
    await image.decode();
    if (image.naturalWidth < 320 || image.naturalHeight < 150 || image.naturalWidth * image.naturalHeight > 24000000) {
      throw new Error('dimensions');
    }
    image.hidden = false;
    el('placeholder').hidden = true;
  } catch {
    el('error').textContent = 'Use a readable image at least 320 × 150 pixels, up to 24 megapixels.';
    event.target.value = '';
    image.removeAttribute('src');
  }
});
fetch('ad-inventory.json').then(response => {
  if (!response.ok) throw new Error('inventory');
  return response.json();
}).then(slots => {
  const select = el('slot');
  select.replaceChildren();
  for (const slot of slots) {
    const option = document.createElement('option');
    option.value = slot.id;
    option.textContent = `${slot.id} · ${slot.size}`;
    select.append(option);
  }
  const requested = new URLSearchParams(location.search).get('slot');
  if (slots.some(slot => slot.id === requested)) select.value = requested;
  summary();
}).catch(() => {
  el('slot').replaceChildren(new Option('Inventory unavailable — reload to try again', ''));
  el('error').textContent = 'The billboard list could not load. No booking or payment has been made.';
});
summary();
