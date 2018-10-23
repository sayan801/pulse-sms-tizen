<template>
    <div class="label mdl-color-text--grey-600"> {{conversationData.label}} </div>
</template>

<script>
export default {
    name: 'day-label',
    props: ['conversationData']
}
</script>

<!-- Add "scoped" attribute to limit CSS to this component only -->
<style lang="scss" scoped>
    @import "../../assets/scss/_vars.scss";

    .label {
        margin: auto;
        text-align: center;
        font-size: 16px;
        margin-top: 10px;
        margin-bottom: 10px;
        font-weight: bold;
    }
</style>
