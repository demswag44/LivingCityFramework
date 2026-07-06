(function() {
    let input = "";
    let unlocked = false;
    let marketData = { items: [], pendingOrders: [], vehicleOffers: [] };
    let isOrderSubmitting = false;
    let isOfferSubmitting = false;
    const cart = new Map();

    function getResourceName() {
        return typeof GetParentResourceName === "function"
            ? GetParentResourceName()
            : "gs_blackmarket";
    }

    function postToLua(name, data) {
        return fetch(`https://${getResourceName()}/${name}`, {
            method: "POST",
            headers: {
                "Content-Type": "application/json; charset=UTF-8",
            },
            body: JSON.stringify(data || {}),
        }).then((response) => response.json()).catch((error) => {
            console.error("[gs_blackmarket] ShadowMarket callback failed", name, error);
            return { ok: false };
        });
    }

    function el(id) {
        return document.getElementById(id);
    }

    function money(value) {
        return `$${Number(value || 0).toLocaleString()}`;
    }

    function formatTime(seconds) {
        const safeSeconds = Math.max(0, Number(seconds || 0));
        const minutes = Math.floor(safeSeconds / 60);
        const remainder = String(safeSeconds % 60).padStart(2, "0");
        return `${minutes}:${remainder}`;
    }

    function badgeKey(value) {
        return String(value || "low").toLowerCase().replace(/[^a-z0-9_-]/g, "");
    }

    function setDisplay(value) {
        const display = el("calculatorDisplay");
        if (display) display.textContent = value || "0";
    }

    function setStatus(message) {
        const status = el("calculatorStatus");
        if (status) status.textContent = message || "";
    }

    function setShadowStatus(message) {
        const status = el("shadowStatus");
        if (status) status.textContent = message || "";
    }

    function setDashboardVisible(visible) {
        el("shadowDashboard")?.classList.toggle("hidden", !visible);
        el("shadowContent")?.classList.toggle("hidden", visible);
    }

    function getCartCount() {
        return Array.from(cart.values()).reduce((total, quantity) => {
            return total + (Number(quantity) || 0);
        }, 0);
    }

    function updateCartCount() {
        const countEl = el("shadowCartCount");
        if (countEl) countEl.textContent = String(getCartCount());
    }

    function findMarketItem(itemIndex) {
        return (marketData.items || []).find((entry) => Number(entry.itemIndex) === Number(itemIndex));
    }

    function getCartPayload() {
        return Array.from(cart.entries()).map(([itemIndex, quantity]) => ({
            itemIndex,
            quantity,
        }));
    }

    function openCartPanel() {
        const panel = el("shadowCartPanel");
        const overlay = el("shadowCartOverlay");

        renderCart();

        if (panel) panel.classList.remove("hidden");
        if (overlay) overlay.classList.remove("hidden");

        setTimeout(() => {
            if (panel) panel.classList.add("open");
            if (overlay) overlay.classList.add("open");
        }, 10);
    }

    function closeCartPanel() {
        const panel = el("shadowCartPanel");
        const overlay = el("shadowCartOverlay");

        if (panel) panel.classList.remove("open");
        if (overlay) overlay.classList.remove("open");

        setTimeout(() => {
            if (panel) panel.classList.add("hidden");
            if (overlay) overlay.classList.add("hidden");
        }, 220);
    }

    function isCartPanelOpen() {
        const panel = el("shadowCartPanel");
        return !!panel && panel.classList.contains("open");
    }

    function refreshMarketData() {
        return postToLua("shadowMarketGetData", {}).then((data) => {
            marketData = data || { items: [], pendingOrders: [] };
            marketData.items = Array.isArray(marketData.items) ? marketData.items : [];
            marketData.pendingOrders = Array.isArray(marketData.pendingOrders) ? marketData.pendingOrders : [];
            marketData.vehicleOffers = Array.isArray(marketData.vehicleOffers) ? marketData.vehicleOffers : [];
            const rep = el("shadowRep");
            const dealer = el("shadowDealer");

            if (rep) rep.textContent = `Dealer Rep: ${Number(marketData.reputation || 0)}`;
            if (dealer) {
                const location = marketData.activeLocation || {};
                dealer.textContent = `Active Dealer: ${location.hint || location.label || "unknown"}`;
            }

            return marketData;
        });
    }

    function renderCart() {
        const cartItems = el("shadowCartItems");
        const totalEl = el("shadowCartTotal");
        const placeButton = el("shadowPlaceOrderBtn");
        if (!cartItems) return;

        let total = 0;
        const lines = [];

        cart.forEach((quantity, itemIndex) => {
            const item = findMarketItem(itemIndex);
            if (!item) return;
            total += Number(item.price || 0) * quantity;
            lines.push(`
                <div class="shadow-cart-item">
                    <div>
                        <strong>${item.label}</strong>
                        <span>${money(Number(item.price || 0) * quantity)}</span>
                    </div>
                    <div class="shadow-quantity">
                        <button data-remove-item="${itemIndex}">-</button>
                        <strong>${quantity}</strong>
                        <button data-increase-item="${itemIndex}">+</button>
                        <button data-delete-item="${itemIndex}">Remove</button>
                    </div>
                </div>
            `);
        });

        cartItems.innerHTML = lines.length
            ? lines.join("")
            : `<div class="shadow-empty">No items selected.</div>`;
        if (totalEl) totalEl.textContent = money(total);
        if (placeButton) placeButton.disabled = isOrderSubmitting || cart.size < 1;

        cartItems.querySelectorAll("[data-remove-item]").forEach((button) => {
            button.addEventListener("click", () => removeFromCart(Number(button.dataset.removeItem)));
        });

        cartItems.querySelectorAll("[data-increase-item]").forEach((button) => {
            button.addEventListener("click", () => addToCart(Number(button.dataset.increaseItem)));
        });

        cartItems.querySelectorAll("[data-delete-item]").forEach((button) => {
            button.addEventListener("click", () => {
                cart.delete(Number(button.dataset.deleteItem));
                renderCart();
            });
        });

        updateCartCount();
    }

    function addToCart(itemIndex) {
        const item = findMarketItem(itemIndex);
        if (!item || item.unlocked === false || Number(item.stock || 0) <= 0) return;

        const current = cart.get(itemIndex) || 0;
        const max = Math.min(Number(item.maxQuantity || 10), Number(item.stock || 0));
        cart.set(itemIndex, Math.min(max, current + 1));
        setShadowStatus("Added to order.");
        renderCart();
    }

    function removeFromCart(itemIndex) {
        const current = cart.get(itemIndex) || 0;

        if (current > 1) {
            cart.set(itemIndex, current - 1);
        }

        renderCart();
    }

    function placeOrder() {
        const payload = getCartPayload();
        const placeButton = el("shadowPlaceOrderBtn");

        if (payload.length < 1) {
            setShadowStatus("Add items to the order first.");
            return;
        }

        if (isOrderSubmitting) return;
        isOrderSubmitting = true;
        if (placeButton) placeButton.disabled = true;

        postToLua("shadowMarketPlaceOrder", { cart: payload }).then((result) => {
            setShadowStatus((result && result.message) || "Order submitted.");
            if (result && result.ok) {
                cart.clear();
                closeCartPanel();
                refreshMarketData().then(renderOrders);
                return;
            }

            renderCart();
        }).finally(() => {
            isOrderSubmitting = false;
            renderCart();
        });
    }

    function renderBuy() {
        setDashboardVisible(false);
        const content = el("shadowContent");
        if (!content) return;

        const items = (marketData.items || []).map((item) => {
            const locked = item.unlocked === false;
            const stock = Number(item.stock || 0);
            const disabled = locked || stock <= 0;
            const reason = locked ? item.lockReason : (stock <= 0 ? "Out of stock" : "Available");

            return `
                <div class="shadow-item-card">
                    <div>
                        <strong>${item.label || "Unknown"}</strong>
                        <span>${item.description || ""}</span>
                    </div>
                    <div class="shadow-item-meta">
                        <span>${money(item.price)}</span>
                        <span>Stock: ${stock}</span>
                        <span>Rep: ${item.requiredRep || 0}</span>
                    </div>
                    <div class="shadow-lock ${disabled ? "locked" : ""}">${reason}</div>
                    <button data-add-item="${item.itemIndex}" ${disabled ? "disabled" : ""}>Add to Order</button>
                </div>
            `;
        }).join("");

        content.innerHTML = `
            <div class="shadowmarket-toolbar">
                <button data-shadow-back class="shadow-secondary-btn">Back</button>
                <strong>Buy</strong>
                <button id="shadowCartToggleBtn" class="shadow-cart-toggle">Cart <span id="shadowCartCount">0</span></button>
            </div>
            <div class="shadow-buy-layout">
                <div class="shadow-item-list">${items || `<div class="shadow-empty">No stock available.</div>`}</div>
            </div>
        `;

        content.querySelectorAll("[data-add-item]").forEach((button) => {
            button.addEventListener("click", () => addToCart(Number(button.dataset.addItem)));
        });

        content.querySelector("#shadowCartToggleBtn")?.addEventListener("click", openCartPanel);
        content.querySelector("[data-shadow-back]")?.addEventListener("click", renderDashboard);
        renderCart();
    }

    function acceptVehicleOffer(offerId) {
        if (isOfferSubmitting) return;

        isOfferSubmitting = true;
        setShadowStatus("Contacting buyer...");

        postToLua("shadowMarketAcceptVehicleOffer", { offerId }).then((result) => {
            isOfferSubmitting = false;
            setShadowStatus((result && result.message) || "Vehicle offer updated.");

            if (result && result.ok) {
                return refreshMarketData().then(renderSell);
            }

            if (result && result.activeVehicleOffer) {
                marketData.activeVehicleOffer = result.activeVehicleOffer;
            }

            renderSell();
            return null;
        }).catch(() => {
            isOfferSubmitting = false;
            setShadowStatus("Vehicle offer could not be accepted.");
            renderSell();
        });
    }

    function renderSell() {
        setDashboardVisible(false);
        closeCartPanel();
        const content = el("shadowContent");
        if (!content) return;

        const active = marketData.activeVehicleOffer;
        const activeHtml = active ? `
            <div class="shadow-offer-active">
                <strong>Active Offer</strong>
                <span>${active.requestLabel || active.label || "Vehicle request"}</span>
                <span>Deliver to: ${active.deliveryLabel || "Benny's"}</span>
                <span>Bonus: ${money(active.finalBonus || active.bonus)}</span>
                <span>Demand: ${active.demandLabel || active.demandLevel || "Normal"}</span>
                <span>Heat: ${active.heatLabel || active.policeHeat || "Low"}</span>
                <span>Expires in: ${formatTime(active.expiresIn)}</span>
            </div>
        ` : "";

        const rows = (marketData.vehicleOffers || []).map((offer) => {
            const locked = offer.unlocked === false;
            const expired = offer.expired || Number(offer.expiresIn || 0) <= 0;
            const hasActive = !!active;
            const disabled = locked || expired || hasActive || isOfferSubmitting;
            const status = expired
                ? "Expired"
                : locked
                ? (offer.lockReason || "Locked")
                : (hasActive ? "Active offer already accepted" : "Available");
            const demandLevel = offer.demandLevel || "normal";
            const heatLevel = offer.heatLevel || "low";

            return `
                <div class="shadow-offer-card">
                    <div>
                        <strong>${offer.label || "Vehicle Offer"}</strong>
                        <span>${offer.requestLabel || "Requested vehicle"}</span>
                    </div>
                    <div class="shadow-offer-badges">
                        <span class="shadow-offer-badge offer-badge-demand-${badgeKey(demandLevel)}">Demand: ${offer.demandLabel || demandLevel}</span>
                        <span class="shadow-offer-badge offer-badge-heat-${badgeKey(heatLevel)}">Heat: ${offer.heatLabel || offer.policeHeat || heatLevel}</span>
                    </div>
                    <div class="shadow-offer-meta">
                        <span>Bonus: ${money(offer.finalBonus || offer.bonus)}</span>
                        <span>Rep: ${offer.requiredRep || 0}</span>
                    </div>
                    <span>Delivery: ${offer.deliveryShopLabel || offer.deliveryLabel || "Benny's"}</span>
                    <span>Expires in: ${formatTime(offer.expiresIn || offer.expiresSeconds)}</span>
                    <div class="shadow-lock ${disabled ? "locked" : ""}">${status}</div>
                    <button data-accept-offer="${offer.id}" ${disabled ? "disabled" : ""}>Accept Offer</button>
                </div>
            `;
        }).join("");

        content.innerHTML = `
            <div class="shadow-panel-header">
                <button data-shadow-back>Back</button>
                <strong>Vehicle Offers</strong>
                <span class="shadow-rotation">Rotation: ${formatTime(marketData.vehicleOfferRotationRemaining)}</span>
            </div>
            ${activeHtml}
            <div class="shadow-offer-list">${rows || `<div class="shadow-empty">No vehicle offers available right now.<br>Check back later.</div>`}</div>
        `;

        content.querySelector("[data-shadow-back]")?.addEventListener("click", renderDashboard);
        content.querySelectorAll("[data-accept-offer]").forEach((button) => {
            button.addEventListener("click", () => acceptVehicleOffer(button.dataset.acceptOffer));
        });
    }

    function renderOrders() {
        setDashboardVisible(false);
        const content = el("shadowContent");
        if (!content) return;

        const orders = marketData.pendingOrders || [];
        const rows = orders.map((order) => {
            const items = (order.items || []).map((item) => `${item.label} x${item.quantity}`).join(", ");

            return `
                <div class="shadow-order-card">
                    <strong>Order #${order.id}</strong>
                    <span>Status: ${order.status}</span>
                    <span>Pickup: ${order.pickup || "Unknown Door"}</span>
                    <span>Expires in: ${formatTime(order.expiresIn)}</span>
                    <span>Total: ${money(order.total)}</span>
                    <span>${items || "No items"}</span>
                </div>
            `;
        }).join("");

        content.innerHTML = `
            <div class="shadow-panel-header">
                <button data-shadow-back>Back</button>
                <strong>Pickup Orders</strong>
            </div>
            <div class="shadow-order-list">${rows || `<div class="shadow-empty">No pending orders.</div>`}</div>
        `;

        content.querySelector("[data-shadow-back]")?.addEventListener("click", renderDashboard);
    }

    function renderDashboard() {
        closeCartPanel();
        setDashboardVisible(true);
        const content = el("shadowContent");
        if (content) content.innerHTML = "";
        refreshMarketData();
    }

    function showCalculator() {
        unlocked = false;
        input = "";
        cart.clear();
        updateCartCount();
        closeCartPanel();
        setDisplay("0");
        el("calculatorMode")?.classList.remove("hidden");
        el("shadowMode")?.classList.add("hidden");
    }

    function showShadowMarket(data) {
        unlocked = true;
        el("calculatorMode")?.classList.add("hidden");
        el("shadowMode")?.classList.remove("hidden");
        setShadowStatus(data.message || "ShadowMarket unlocked.");
        refreshMarketData().then(renderDashboard);
    }

    function openPhone(data) {
        const app = el("shadowMarketApp");
        if (!app) return;

        document.body.style.display = "block";
        document.body.style.visibility = "visible";
        document.body.style.opacity = "1";

        const visibleName = el("shadowVisibleName");
        const hiddenName = el("shadowHiddenName");

        if (visibleName) visibleName.textContent = data.visibleName || "Calculator";
        if (hiddenName) hiddenName.textContent = data.hiddenName || "ShadowMarket";

        app.classList.remove("hidden");
        showCalculator();
        setStatus("");
        postToLua("shadowMarketOpened", { ok: true });
    }

    function closePhone() {
        const app = el("shadowMarketApp");
        if (app) app.classList.add("hidden");
        closeCartPanel();
        showCalculator();
        postToLua("shadowMarketClose", { ok: true });
    }

    function handleCalculator(value) {
        if (value === "clear") {
            input = "";
            setStatus("");
            setDisplay("0");
            return;
        }

        if (value === "back") {
            input = input.slice(0, -1);
            setDisplay(input || "0");
            return;
        }

        if (value === "equals") {
            postToLua("shadowMarketUnlock", { code: input }).then((result) => {
                if (result && result.ok) {
                    showShadowMarket(result);
                    return;
                }

                setStatus((result && result.message) || "Invalid calculation.");
                input = "";
                setDisplay("0");
            });
            return;
        }

        if (input.length >= 12) return;
        input += value;
        setDisplay(input);
    }

    window.addEventListener("DOMContentLoaded", function() {
        document.querySelectorAll("[data-calc]").forEach((button) => {
            button.addEventListener("click", function() {
                handleCalculator(this.dataset.calc);
            });
        });

        el("shadowCloseBtn")?.addEventListener("click", closePhone);
        el("shadowExitBtn")?.addEventListener("click", closePhone);
        el("shadowBuyBtn")?.addEventListener("click", () => refreshMarketData().then(renderBuy));
        el("shadowSellBtn")?.addEventListener("click", () => {
            refreshMarketData().then(renderSell);
        });
        el("shadowPickupBtn")?.addEventListener("click", () => refreshMarketData().then(renderOrders));
        el("shadowCartCloseBtn")?.addEventListener("click", closeCartPanel);
        el("shadowCartOverlay")?.addEventListener("click", closeCartPanel);
        el("shadowClearCartBtn")?.addEventListener("click", () => {
            cart.clear();
            setShadowStatus("Order cart cleared.");
            renderCart();
        });
        el("shadowPlaceOrderBtn")?.addEventListener("click", placeOrder);

        el("shadowWipeBtn")?.addEventListener("click", function() {
            postToLua("shadowMarketWipe", {}).then((result) => {
                setShadowStatus((result && result.message) || "App data wiped.");
                closePhone();
            });
        });

        document.addEventListener("keydown", function(event) {
            const app = el("shadowMarketApp");
            if (!app || app.classList.contains("hidden")) return;

            if (event.key === "Escape") {
                if (isCartPanelOpen()) {
                    closeCartPanel();
                    return;
                }

                closePhone();
                return;
            }

            if (!unlocked && /^[0-9.]$/.test(event.key)) handleCalculator(event.key);
            if (!unlocked && event.key === "Enter") handleCalculator("equals");
            if (!unlocked && event.key === "Backspace") handleCalculator("back");
        });
    });

    window.addEventListener("message", function(event) {
        const data = event.data || {};

        if (data.action === "shadowmarketOpen") {
            openPhone(data);
        }

        if (data.action === "shadowmarketClose") {
            const app = el("shadowMarketApp");
            if (app) app.classList.add("hidden");
            closeCartPanel();
            showCalculator();
        }
    });
})();
