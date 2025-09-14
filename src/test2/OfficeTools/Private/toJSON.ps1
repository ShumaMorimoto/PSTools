toJSON() {
        return ConvertTo-JSON -depth 3 $this.toObject()
    }
