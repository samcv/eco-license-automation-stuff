use fetch;
sub get-license-json {
    my (Str:D $json-txt, Int:D $exitcode) = fetch-url 'https://raw.githubusercontent.com/sindresorhus/spdx-license-list/master/spdx-full.json';
    note $exitcode == 0 ?? "Done downloading file" !! "failed downloading file";
    use JSON::Fast;
    from-json($json-txt);
}
sub normalize-license (Str $text) {
    $text.lc;
}

sub s(Bag:D \x) { x.values.sum };
sub similarity(Bag:D \a, Bag:D \b) {2 * s(a ∩ b) / (s(a) + s(b)) };
sub get-bags (%json) {
    my %values;
    note "Creating Bag's";
    for %json.keys {
        die "No licenseText found for $_" unless %json{$_}<licenseText>;
        my $bag = normalize-license(%json{$_}<licenseText>).words.Bag;
        die unless $bag ~~ Bag;
        %values{$_} = $bag;
    }
    %values;
}
sub compare-them ($text2) is export {
    state %json = get-license-json;
    state %values = get-bags(%json);
    my @words2 = normalize-license($text2).words;
    my %similarity;

    note "Finding similarity";
    for %values.keys {
        %similarity{$_} = similarity(%values{$_}, @words2.Bag);
    }
    my @sorted = %similarity.sort({$^b.value <=> $^a.value});
    if @sorted[0].value > 0.995 {
        my $is = @sorted[0];
        note "Project is {$is.key} with {$is.value *100}% certainty";
        return $is.key;
    }
    else {
        note "Less than 99.5% certainty. Found these candidates:";
        note @sorted.head(3);
        return False;
    }

}
sub get-count (%hash1, %hash2, Bool:D :$second-run = False) {
    my Int $count = 0;
    for %hash1.sort(*.value.Int) -> $pair {
        my ($word, $num) = $pair.key, $pair.value;
        if  %hash2{$word}:exists {
            next if $second-run;
            my $found = $num - %hash2{$word};
            note "Found “$word” $found times compared to text2" if $found != 0;
            $count += abs($found);
        }
        else {
            note "Found “$word” $num times is in text1 but NOT text2";
            $count += $num;
        }
    }
    return $count;
}
