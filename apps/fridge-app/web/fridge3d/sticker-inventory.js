import { DRAWERS, normalizeFoods } from './fridge-state.js?rev=fridge-sticker-grid-v2.3';
import { projectStickerSlot, stickerLayout } from './sticker-layout.js?rev=fridge-sticker-grid-v2.3';

export class StickerInventory {
  #layer = document.querySelector('#sticker-layer');
  #pager = document.querySelector('#sticker-pager');
  #previous = document.querySelector('#sticker-previous');
  #next = document.querySelector('#sticker-next');
  #pageLabel = document.querySelector('#sticker-page');
  #foods = [];
  #revision = 0;
  #pages = { fresh: 0, variable: 0, freezer: 0 };
  #zone = 'fresh';
  #signature = '';
  #entries = [];

  constructor(onSelect, requestRender) {
    this.onSelect = onSelect;
    for (const [button, direction] of [[this.#previous, -1], [this.#next, 1]]) {
      button.addEventListener('click', () => {
        this.#pages[this.#zone] += direction;
        requestRender();
      });
    }
  }

  replace(foods, revision) {
    this.#foods = normalizeFoods(foods);
    this.#revision = revision;
    this.#signature = '';
    return this.#foods.length;
  }

  render(view, animated, camera, width, height) {
    const zone = view.focus ?? 'fresh';
    const drawer = DRAWERS[zone];
    const readyView = {
      ...view,
      leftDoor: view.leftDoor && animated.leftDoor > 0.63,
      rightDoor: view.rightDoor && animated.rightDoor > 0.63,
    };
    if (drawer && animated[drawer.part] <= 0.82) readyView[drawer.part] = 0;
    const openDrawer = drawer ? readyView[drawer.part] : 0;
    const layoutKey = [zone, openDrawer, readyView.leftDoor, readyView.rightDoor].join('/');
    if (`${layoutKey}/${this.#pages[zone]}` !== this.#signature) this.#showPage(zone, readyView);

    const drawerOffset = drawer ? (animated[drawer.part] - 1) * drawer.travel : 0;
    for (const { button, slot } of this.#entries) {
      const { x, y, size } = projectStickerSlot(slot, camera, width, height, drawerOffset);
      button.hidden = !(size > 0);
      if (button.hidden) continue;
      button.style.left = `${x.toFixed(2)}px`;
      button.style.top = `${y.toFixed(2)}px`;
      button.style.setProperty('--sticker-size', `${size.toFixed(1)}px`);
    }
    this.#signature = `${layoutKey}/${this.#pages[zone]}`;
  }

  #showPage(zone, view) {
    this.#zone = zone;
    const foods = this.#foods.filter((food) => food.zone === zone);
    const { capacity, slots } = stickerLayout(zone, view, foods.length);
    const last = Math.max(0, Math.ceil(foods.length / capacity) - 1);
    const page = this.#pages[zone] = Math.min(last, Math.max(0, this.#pages[zone]));
    const start = page * capacity;
    this.#entries = slots
      .filter((slot) => foods[start + slot.index])
      .map((slot) => ({ button: this.#button(foods[start + slot.index], slot.index), slot }));
    this.#layer.dataset.capacity = String(capacity);
    this.#layer.replaceChildren(...this.#entries.map(({ button }) => button));
    this.#pager.hidden = slots.length === 0 || last === 0;
    this.#previous.disabled = page === 0;
    this.#next.disabled = page >= last;
    this.#pageLabel.textContent = `${page + 1} / ${last + 1}`;
  }

  #button(food, index) {
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'inventory-sticker';
    button.dataset.foodId = food.id;
    button.dataset.slot = String(index);
    button.setAttribute('aria-label', food.name);
    if (food.portions) button.setAttribute('aria-description', `${food.portions} 份`);
    button.style.setProperty('--phase', `${(index % 7) * -0.37}s`);
    const picture = document.createElement('span');
    picture.className = 'sticker-picture';
    const fallback = document.createElement('span');
    fallback.hidden = Boolean(food.artwork);
    for (let layer = food.layers - 1; layer >= 0; layer--) {
      const emoji = document.createElement('span');
      emoji.className = 'sticker-emoji';
      if (layer > 0) {
        emoji.classList.add('sticker-underlay');
        emoji.style.setProperty('--layer', String(layer));
      }
      emoji.textContent = food.emoji;
      fallback.append(emoji);
    }
    if (food.artwork) {
      // Flutter's web build writes non-ASCII asset names as URI-encoded filenames.
      const filename = encodeURIComponent(food.artwork);
      const src = `../assets/assets/images/ingredient-stickers/${encodeURIComponent(filename)}.webp`;
      for (let layer = food.layers - 1; layer >= 0; layer--) {
        const image = document.createElement('img');
        image.className = 'sticker-artwork';
        if (layer > 0) {
          image.classList.add('sticker-underlay');
          image.style.setProperty('--layer', String(layer));
        }
        image.alt = '';
        image.draggable = false;
        image.addEventListener('error', () => {
          for (const artwork of picture.querySelectorAll('img')) artwork.remove();
          fallback.hidden = false;
        }, { once: true });
        image.src = src;
        picture.append(image);
      }
    }
    picture.append(fallback);
    if (food.portions) {
      const badge = document.createElement('span');
      badge.className = 'sticker-portions';
      badge.setAttribute('aria-hidden', 'true');
      badge.textContent = Number(food.portions) > 99 ? '99+' : food.portions;
      picture.append(badge);
    }
    const label = document.createElement('span');
    label.className = 'sticker-name';
    label.textContent = food.name;
    label.setAttribute('aria-hidden', 'true');
    const revision = this.#revision;
    button.addEventListener('click', () => this.onSelect(food.id, revision));
    button.append(picture, label);
    return button;
  }
}
