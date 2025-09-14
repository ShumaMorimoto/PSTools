getSyukujitsu([datetime]$st) {
        return [OTCalDAO]::getSyukujitsu($st, $st.AddYears(1))
    }
