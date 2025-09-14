PrevMonth() {
        return New-Object Term($this.base.addMonts(-1), 1)
    }
