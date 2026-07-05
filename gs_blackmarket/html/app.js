console.log("[gs_blackmarket] app.js loaded");

let state = {
    visible: false,
    locationId: null,
    items: [],
    cart: [],
    quantities: {},
    activeCategory: "all",
    assetPath: "assets/",
    maxQuantity: 10,
    restockRemaining: 0,
};

function postToLua(name, data) {
    const resourceName = typeof GetParentResourceName === "function"
        ? GetParentResourceName()
        : "gs_blackmarket";

    fetch(`https://${resourceName}/${name}`, {
        method: "POST",
        headers: {
            "Content-Type": "application/json; charset=UTF-8",
        },
        body: JSON.stringify(data || {}),
    }).catch((error) => {
        console.error("[gs_blackmarket] postToLua failed", name, error);
    });
}

window.addEventListener("DOMContentLoaded", function() {
    console.log("[gs_blackmarket] DOM ready");

    const app = document.getElementById("app");

    if (app) {
        app.classList.add("hidden");
        app.style.display = "none";
    }

    bindStaticButtons();
    renderCart();
    renderRestockTimer();

    setInterval(tickRestockTimer, 1000);

    postToLua("uiReady", { ok: true });
});

window.addEventListener("message", function(event) {
    const data = event.data || {};
    console.log("[gs_blackmarket] message received", data);

    if (data.action === "open") {
        openMarket(data);
    }

    if (data.action === "close") {
        closeMarket(false);
    }

    if (data.action === "ping") {
        forceVisiblePing();
    }
});

function openMarket(data) {
    const app = document.getElementById("app");

    if (!app) {
        console.error("[gs_blackmarket] #app missing");
        postToLua("uiOpened", { ok: false });
        return;
    }

    document.body.style.display = "block";
    document.body.style.visibility = "visible";
    document.body.style.opacity = "1";

    state.visible = true;
    state.locationId = data.locationId;
    state.items = Array.isArray(data.items) ? data.items : [];
    state.cart = [];
    state.quantities = {};
    state.activeCategory = "all";
    state.assetPath = normalizeAssetPath(data.assetPath || "assets/");
    state.maxQuantity = Number(data.maxQuantity) || 10;
    state.restockRemaining = Number(data.restockRemaining) || 0;

    const title = document.getElementById("marketTitle");
    const subtitle = document.getElementById("marketSubtitle");

    if (title) {
        title.textContent = data.title || "Black Market";
    }

    if (subtitle) {
        subtitle.textContent = data.subtitle || "No refunds. No questions.";
    }

    const purchaseBtn = document.getElementById("purchaseBtn");
    if (purchaseBtn) {
        purchaseBtn.disabled = false;
    }

    app.classList.remove("hidden");
    app.style.display = "flex";
    app.style.visibility = "visible";
    app.style.opacity = "1";

    setActiveCategory("all");
    renderItems();
    renderCart();
    renderRestockTimer();

    console.log("[gs_blackmarket] full shop UI opened");
    postToLua("uiOpened", { ok: true });
}

function closeMarket(sendCloseCallback) {
    const app = document.getElementById("app");

    state.visible = false;
    state.cart = [];
    state.quantities = {};
    state.restockRemaining = 0;
    renderCart();
    renderRestockTimer();

    if (app) {
        app.classList.add("hidden");
        app.style.display = "none";
    }

    if (sendCloseCallback) {
        postToLua("close", {});
    }

    console.log("[gs_blackmarket] full shop UI closed");
}

function forceVisiblePing() {
    const app = document.getElementById("app");

    document.body.style.display = "block";
    document.body.style.visibility = "visible";
    document.body.style.opacity = "1";

    if (app) {
        app.classList.remove("hidden");
        app.style.display = "flex";
        app.style.visibility = "visible";
        app.style.opacity = "1";
    }

    console.log("[gs_blackmarket] ping made UI visible");
    postToLua("uiOpened", { ok: true, source: "ping" });
}

function bindStaticButtons() {
    document.querySelectorAll(".category-btn").forEach((button) => {
        button.addEventListener("click", function() {
            setActiveCategory(this.dataset.category || "all");
            renderItems();
        });
    });

    const leaveBtn = document.getElementById("leaveBtn");
    const clearCartBtn = document.getElementById("clearCartBtn");
    const purchaseBtn = document.getElementById("purchaseBtn");

    if (leaveBtn) {
        leaveBtn.addEventListener("click", function() {
            closeMarket(true);
        });
    }

    if (clearCartBtn) {
        clearCartBtn.addEventListener("click", function() {
            state.cart = [];
            renderCart();
        });
    }

    if (purchaseBtn) {
        purchaseBtn.addEventListener("click", function() {
            if (!state.cart.length) {
                return;
            }

            purchaseBtn.disabled = true;

            postToLua("purchase", {
                locationId: state.locationId,
                cart: state.cart.map((line) => ({
                    itemIndex: line.itemIndex,
                    quantity: line.quantity,
                })),
            });

            state.cart = [];
            renderCart();
            closeMarket(true);
        });
    }

    document.addEventListener("keydown", function(event) {
        if (event.key === "Escape" && state.visible) {
            closeMarket(true);
        }
    });
}

function setActiveCategory(category) {
    state.activeCategory = category || "all";

    document.querySelectorAll(".category-btn").forEach((button) => {
        button.classList.toggle("active", button.dataset.category === state.activeCategory);
    });
}

function normalizeAssetPath(path) {
    const next = String(path || "assets/");

    if (next === "html/assets/" || next.startsWith("html/assets/")) {
        return "assets/";
    }

    return next.endsWith("/") ? next : `${next}/`;
}

function formatMoney(value) {
    return `$${Number(value || 0).toLocaleString()}`;
}

function escapeHtml(value) {
    const div = document.createElement("div");
    div.textContent = String(value || "");
    return div.innerHTML;
}

function getItemMaxQuantity(item) {
    const itemMax = Number(item.maxQuantity);
    const stockLimited = item.stock !== undefined && item.stock !== null;
    const stock = Number(item.stock);
    let max = state.maxQuantity || 10;

    if (itemMax > 0) {
        max = Math.min(max, itemMax);
    }

    if (stockLimited) {
        max = Math.min(max, Math.max(0, stock || 0));
    }

    return max;
}

function getQuantityForItem(itemIndex) {
    const item = state.items[itemIndex - 1];
    const max = item ? getItemMaxQuantity(item) : state.maxQuantity;

    if (max <= 0) {
        state.quantities[itemIndex] = 0;
        return 0;
    }

    if (!state.quantities[itemIndex]) {
        state.quantities[itemIndex] = 1;
    }

    state.quantities[itemIndex] = Math.max(1, Math.min(max, state.quantities[itemIndex]));

    return state.quantities[itemIndex];
}

function setQuantityForItem(itemIndex, quantity) {
    const item = state.items[itemIndex - 1];
    if (!item) {
        return;
    }

    const max = getItemMaxQuantity(item);
    if (max <= 0) {
        state.quantities[itemIndex] = 0;

        const el = document.querySelector(`[data-qty-value="${itemIndex}"]`);
        if (el) {
            el.textContent = "0";
        }

        return;
    }

    const safeQuantity = Math.max(1, Math.min(max, Number(quantity) || 1));

    state.quantities[itemIndex] = safeQuantity;

    const el = document.querySelector(`[data-qty-value="${itemIndex}"]`);
    if (el) {
        el.textContent = safeQuantity;
    }
}

function renderItems() {
    const grid = document.getElementById("itemGrid");
    if (!grid) {
        return;
    }

    grid.innerHTML = "";

    const filteredItems = state.items
        .map((item, index) => ({ item, itemIndex: index + 1 }))
        .filter(({ item }) => {
            if (state.activeCategory === "all") {
                return true;
            }

            return item.category === state.activeCategory;
        });

    if (!filteredItems.length) {
        grid.innerHTML = '<div class="cart-empty">No items available.</div>';
        return;
    }

    filteredItems.forEach(({ item, itemIndex }) => {
        const quantity = getQuantityForItem(itemIndex);
        const image = item.image ? `${state.assetPath}${item.image}` : "";
        const category = item.category || "unknown";
        const label = item.label || "Unknown Item";
        const description = item.description || "";
        const hasStockLimit = item.stock !== undefined && item.stock !== null;
        const stock = Number(item.stock) || 0;
        const outOfStock = hasStockLimit && stock <= 0;
        const stockLabel = hasStockLimit
            ? (outOfStock ? "Out of Stock" : `Stock: ${stock}`)
            : "Stock: Available";

        const card = document.createElement("div");
        card.className = "item-card";

        card.innerHTML = `
            <div class="item-top">
                ${image ? `<img class="item-img" src="${escapeHtml(image)}" alt="${escapeHtml(label)}">` : `<div class="item-placeholder">?</div>`}
                <div>
                    <div class="item-name">${escapeHtml(label)}</div>
                    <div class="item-category">${escapeHtml(category)}</div>
                </div>
            </div>

            <div class="item-desc">${escapeHtml(description)}</div>
            <div class="item-price">${formatMoney(item.price)}</div>
            <div class="item-stock ${outOfStock ? "out" : ""}">${escapeHtml(stockLabel)}</div>

            <div class="quantity-row">
                <button class="qty-btn" data-qty-minus="${itemIndex}" ${outOfStock ? "disabled" : ""}>-</button>
                <span class="qty-value" data-qty-value="${itemIndex}">${quantity}</span>
                <button class="qty-btn" data-qty-plus="${itemIndex}" ${outOfStock ? "disabled" : ""}>+</button>
            </div>

            <button class="add-btn" data-add-index="${itemIndex}" ${outOfStock ? "disabled" : ""}>${outOfStock ? "Out of Stock" : "Add to Cart"}</button>
        `;

        const img = card.querySelector("img");
        if (img) {
            img.addEventListener("error", function() {
                const fallback = document.createElement("div");
                fallback.className = "item-placeholder";
                fallback.textContent = label.slice(0, 2).toUpperCase();
                img.replaceWith(fallback);
            }, { once: true });
        }

        grid.appendChild(card);
    });

    bindItemButtons();
}

function bindItemButtons() {
    document.querySelectorAll("[data-qty-minus]").forEach((button) => {
        button.addEventListener("click", function() {
            const itemIndex = Number(this.dataset.qtyMinus);
            setQuantityForItem(itemIndex, getQuantityForItem(itemIndex) - 1);
        });
    });

    document.querySelectorAll("[data-qty-plus]").forEach((button) => {
        button.addEventListener("click", function() {
            const itemIndex = Number(this.dataset.qtyPlus);
            setQuantityForItem(itemIndex, getQuantityForItem(itemIndex) + 1);
        });
    });

    document.querySelectorAll("[data-add-index]").forEach((button) => {
        button.addEventListener("click", function() {
            const itemIndex = Number(this.dataset.addIndex);
            addToCart(itemIndex, getQuantityForItem(itemIndex));
        });
    });
}

function addToCart(itemIndex, quantity) {
    const item = state.items[itemIndex - 1];
    if (!item) {
        return;
    }

    const max = getItemMaxQuantity(item);
    if (max <= 0) {
        return;
    }

    const safeQuantity = Math.max(1, Math.min(max, Number(quantity) || 1));
    const existing = state.cart.find((line) => line.itemIndex === itemIndex);

    if (existing) {
        existing.quantity = Math.min(max, existing.quantity + safeQuantity);
    } else {
        state.cart.push({
            itemIndex,
            quantity: safeQuantity,
        });
    }

    renderCart();
}

function updateCartQuantity(itemIndex, delta) {
    const item = state.items[itemIndex - 1];
    const line = state.cart.find((entry) => entry.itemIndex === itemIndex);

    if (!item || !line) {
        return;
    }

    const max = getItemMaxQuantity(item);
    if (max <= 0) {
        removeFromCart(itemIndex);
        return;
    }

    line.quantity = Math.max(1, Math.min(max, line.quantity + delta));

    renderCart();
}

function removeFromCart(itemIndex) {
    state.cart = state.cart.filter((line) => line.itemIndex !== itemIndex);
    renderCart();
}

function renderCart() {
    const cartItems = document.getElementById("cartItems");
    const cartTotal = document.getElementById("cartTotal");

    if (!cartItems || !cartTotal) {
        return;
    }

    cartItems.innerHTML = "";

    if (!state.cart.length) {
        cartItems.innerHTML = '<div class="cart-empty">No items selected.</div>';
        cartTotal.textContent = "$0";
        return;
    }

    let total = 0;

    state.cart.forEach((line) => {
        const item = state.items[line.itemIndex - 1];
        if (!item) {
            return;
        }

        const quantity = Number(line.quantity) || 1;
        const subtotal = Number(item.price || 0) * quantity;
        total += subtotal;

        const row = document.createElement("div");
        row.className = "cart-line";

        row.innerHTML = `
            <div class="cart-line-top">
                <span class="cart-line-name">${escapeHtml(item.label || "Unknown")} x${quantity}</span>
                <span class="cart-line-subtotal">${formatMoney(subtotal)}</span>
            </div>
            <div class="cart-line-controls">
                <button data-cart-minus="${line.itemIndex}">-</button>
                <button data-cart-plus="${line.itemIndex}">+</button>
                <button data-cart-remove="${line.itemIndex}">Remove</button>
            </div>
        `;

        cartItems.appendChild(row);
    });

    cartTotal.textContent = formatMoney(total);

    bindCartButtons();
}

function bindCartButtons() {
    document.querySelectorAll("[data-cart-minus]").forEach((button) => {
        button.addEventListener("click", function() {
            updateCartQuantity(Number(this.dataset.cartMinus), -1);
        });
    });

    document.querySelectorAll("[data-cart-plus]").forEach((button) => {
        button.addEventListener("click", function() {
            updateCartQuantity(Number(this.dataset.cartPlus), 1);
        });
    });

    document.querySelectorAll("[data-cart-remove]").forEach((button) => {
        button.addEventListener("click", function() {
            removeFromCart(Number(this.dataset.cartRemove));
        });
    });
}

function formatRestockTime(seconds) {
    seconds = Math.max(0, Number(seconds) || 0);

    if (seconds <= 0) {
        return "Restock soon";
    }

    const minutes = Math.floor(seconds / 60);
    const remainingSeconds = seconds % 60;

    return `Restock: ${String(minutes).padStart(2, "0")}:${String(remainingSeconds).padStart(2, "0")}`;
}

function renderRestockTimer() {
    const timer = document.getElementById("restockTimer");
    if (!timer) {
        return;
    }

    timer.textContent = formatRestockTime(state.restockRemaining);
}

function tickRestockTimer() {
    if (!state.visible) {
        return;
    }

    if (state.restockRemaining > 0) {
        state.restockRemaining -= 1;
    }

    renderRestockTimer();
}
