function c = getConditionLabel(sf)

if sf == 1
    c = 'Normal';
elseif sf == 0.3
    c = 'Recovery';
else
    c = 'Failing';
end

end
