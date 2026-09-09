// Package pricing computes cart and line totals in whole cents.
//
// All money in this codebase is an integer number of cents. Floats appear
// only inside a single calculation, never to carry a value across a boundary.
package pricing

import "math"

// Line is one row in a cart.
type Line struct {
	SKU       string `json:"sku"`
	UnitCents int    `json:"unit_cents"`
	Qty       int    `json:"qty"`
}

// Discount is a percentage off, e.g. 12.5 means "12.5% off".
type Discount float64

// LineTotal is the discounted price of a single row, in cents.
// The storefront renders this next to each line in the cart.
func LineTotal(l Line, d Discount) int {
	gross := float64(l.UnitCents * l.Qty)
	return int(gross * (1 - float64(d)/100))
}

// CartTotal is the amount we authorise against the customer's card, in cents.
//
// Rounding happens once, on the exact sum, after every line has been combined.
// The payment processor computes its expected total the same way, so the two
// have to agree to the cent.
//
// TODO(pricing): this repeats the discount maths in LineTotal.
func CartTotal(lines []Line, d Discount) int {
	var exact float64
	for _, l := range lines {
		exact += float64(l.UnitCents*l.Qty) * (1 - float64(d)/100)
	}
	return int(math.Round(exact))
}
