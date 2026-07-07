// Minimal DynamoDB AttributeValue unmarshaller so the package stays
// dependency-free and its tests run offline. Numbers are converted with
// Number(): values beyond Number.MAX_SAFE_INTEGER lose precision - store such
// identifiers as strings (S), which single-table designs do anyway.
export const unmarshall = (attributeMap) => {
  if (attributeMap === undefined || attributeMap === null) return undefined;
  const result = {};
  for (const [key, value] of Object.entries(attributeMap)) {
    result[key] = unmarshallValue(value);
  }
  return result;
};

const unmarshallValue = (attribute) => {
  if (attribute === undefined || attribute === null) return undefined;
  const [type] = Object.keys(attribute);
  const value = attribute[type];
  switch (type) {
    case "S":
      return value;
    case "N":
      return Number(value);
    case "BOOL":
      return value === true || value === "true";
    case "NULL":
      return null;
    case "M":
      return unmarshall(value);
    case "L":
      return value.map(unmarshallValue);
    case "SS":
      return [...value];
    case "NS":
      return value.map(Number);
    case "B":
    case "BS":
      return value; // base64 as delivered; decoding is the handler's choice
    default:
      throw new Error(`unmarshall: unsupported AttributeValue type "${type}"`);
  }
};
