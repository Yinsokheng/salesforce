import { LightningElement, api } from 'lwc';

export default class InterfaceTreeNode extends LightningElement {
    @api node;

    get isIntegration() {
        return this.node.type === 'integration';
    }

    get isInterface() {
        return this.node.type === 'interface';
    }

    get isMessage() {
        return this.node.type === 'message';
    }

    get hasChildren() {
        return this.node.hasChildren;
    }

    handleToggle() {
        this.dispatchEvent(new CustomEvent('toggle', {
            bubbles: true,
            composed: true,
            detail: { nodeId: this.node.id }
        }));
    }

    handleSelect() {
        this.dispatchEvent(new CustomEvent('select', {
            bubbles: true,
            composed: true,
            detail: { nodeId: this.node.id }
        }));
    }
}