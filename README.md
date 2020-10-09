Generate novelty election maps

Using the data and model from [Cook Political Report](https://cookpolitical.com/swingometer), this tries to optimize an election outcome based on some loss function.

Perhaps more notably, this includes a pretty decent black-box optimizer. While it was written specifically for this project, it's still fundamentally an implementation of [SPSA](https://en.wikipedia.org/wiki/Simultaneous_perturbation_stochastic_approximation), and it's a generic one at that. As a result, it can be used for a variety of other problems.