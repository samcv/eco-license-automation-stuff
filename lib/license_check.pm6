use fetch;
use OO::Monitors;
use JSON::Fast;
state $values-mon;
monitor mon-hash {
    has %!hash;
    method get { %!hash };
    method set (%new-hash) { %!hash = %new-hash }
}
sub init-mon {
    unless $values-mon {
        $values-mon = mon-hash.new;
        $values-mon.set:  get-bags(get-license-json);
    }
}
sub get-license-json {
    my (Str:D $json-txt, Int:D $exitcode) = fetch-url 'https://raw.githubusercontent.com/sindresorhus/spdx-license-list/master/spdx-full.json';
    note $exitcode == 0 ?? "Done downloading file" !! "failed downloading file";
    from-json($json-txt);
}
sub normalize-license (Str:D $text) {
    $text.lc;
}

sub s(Bag:D \x) { x.values.sum };
sub similarity(Bag:D \a, Bag:D \b) {2 * s(a ∩ b) / (s(a) + s(b)) };
sub get-bags (%json) {
    note "Creating Bag's";
    my @proms;
    await do for %json.keys.rotor(3, :partial) -> $keys {
        @proms.push: start {
          my @list;
          for $keys.list {
            die "file didn't download properly?" unless %json{$_}<licenseText>;
           @list.append: $_, normalize-license(%json{$_}<licenseText>).words.Bag;
         }
         @list;
      }
    }
    my @new;
    for @proms -> $prom {
      @new.push: $_ for $prom.result;
    }
  #  my $thing = $proms».result;
    #say $thing.elems;
    #say $thing.hash.keys;
    my %values = @new.hash;
    #say %values.keys;
  #  die unless %values.elems;
    %values;
}

sub compare-them ($text2) is export {
    INIT init-mon;
    my @words2 = normalize-license($text2).words;
    my %similarity;
    my %values = $values-mon.get;
    my $words2-bag = @words2.Bag;
    note "Finding similarity";
    for %values.keys {
        %similarity{$_} = similarity(%values{$_}, $words2-bag);
    }
    my @sorted = %similarity.sort({$^b.value <=> $^a.value});
    my $diff-words = (1 - @sorted[0].value) * @words2.elems;
    note "Estimate about $diff-words different";
    if @sorted[0].value > 0.995 or $diff-words <=4 {
        my $is = @sorted[0];
        note "Project is {$is.key} with {$is.value *100}% certainty";
        return True, $is.key;
    }
    else {
        note "Less than 99.5% certainty. Found these candidates: ", @sorted.head(3);
        return (False, @sorted.head(3));
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
