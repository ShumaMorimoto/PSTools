SearchRows([ScriptBlock] $compfunc) {
        return ($this.oRows | Where-Object { &$compfunc $_ } )
    }
