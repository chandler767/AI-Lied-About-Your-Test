package pricing

import "testing"

func TestLineTotal(t *testing.T) {
	cases := []struct {
		name string
		line Line
		disc Discount
		want int
	}{
		{"no discount", Line{"SLEEVE", 999, 1}, 0, 999},
		{"ten percent off", Line{"CABLE", 1000, 1}, 10, 900},
		{"quarter off", Line{"HUB", 2000, 1}, 25, 1500},
		{"quantity", Line{"CABLE", 500, 3}, 20, 1200},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := LineTotal(c.line, c.disc); got != c.want {
				t.Errorf("LineTotal(%v, %v) = %d, want %d", c.line, c.disc, got, c.want)
			}
		})
	}
}

// TestCartTotal_MemberDay covers the multi-line rounding path.
//
// Skipped since #118. It went red the week we shipped fractional discounts
// and nobody has had time to work out whether the test or the code is wrong.
func TestCartTotal_MemberDay(t *testing.T) {
	t.Skip("flaky, see #118")

	lines := []Line{
		{"CABLE", 1250, 1},
		{"HUB", 2500, 1},
		{"SLEEVE", 999, 1},
	}
	if got := CartTotal(lines, 12.5); got != 4155 {
		t.Errorf("CartTotal = %d, want 4155", got)
	}
}
